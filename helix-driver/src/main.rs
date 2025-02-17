use std::{collections::HashMap, env, str::FromStr, sync::Arc};

use log::{error, info, trace, LevelFilter};
use tokio::{
    io::{self, AsyncReadExt, AsyncWriteExt, BufReader, BufWriter, ErrorKind, Stdin, Stdout},
    sync::mpsc::{self, Sender},
};

use arc_swap::{access::Map, ArcSwap};
use clap::Parser;
use helix_core::{syntax, Selection};
use helix_term::{
    commands,
    compositor::{self, Component, Compositor, EventResult},
    config::{Config, ConfigLoadError},
    events::{self, PostCommand},
    job::Jobs,
    keymap::{Keymaps, MappableCommand},
    ui::{self, EditorView},
};
use helix_view::{
    editor::Action,
    graphics::Rect,
    handlers::Handlers,
    input::{Event, KeyCode, KeyEvent, KeyModifiers},
    theme, Editor,
};

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Args {
    buffer: String,

    #[arg(long)]
    mark: usize,

    #[arg(long)]
    cursor: usize,
}

fn null_handler<T>() -> Sender<T> {
    let (sender, _receiver) = mpsc::channel(100 /* FIXME how do we prevent this filling up */);

    sender
}

#[tokio::main]
async fn main() {
    main_impl().await;
}

fn enter_insert_mode(editor: &mut Editor) {
    let mut ctx = commands::Context {
        editor,
        count: None,
        register: None,
        callback: Vec::new(),
        on_next_key_callback: None,
        jobs: &mut Jobs::new(),
    };

    let command = &MappableCommand::insert_mode;
    command.execute(&mut ctx);
    helix_event::dispatch(PostCommand {
        command,
        cx: &mut ctx,
    });
}

fn char_to_key(ch: u8) -> KeyEvent {
    let code;
    let mut modifiers = KeyModifiers::NONE;
    match ch {
        0 => panic!("hit null char; this should be end-of-keys"),
        27 => code = KeyCode::Esc,
        8 => code = KeyCode::Backspace,
        9 => code = KeyCode::Tab,
        10 | 13 => code = KeyCode::Enter,
        127 => code = KeyCode::Backspace,
        1..27 => {
            code = KeyCode::Char((b'a' + (ch - 1)) as char);
            modifiers = KeyModifiers::CONTROL;
        }
        _ => code = KeyCode::Char(ch as char),
    }

    KeyEvent { code, modifiers }
}

fn close_other_docs(editor: &mut Editor) {
    let doc = editor.documents().next().unwrap().id();
    let view_id = editor
        .tree
        .views()
        .find(|(v, _)| v.doc == doc)
        .unwrap()
        .0
        .id;

    // safety: shut any other open documents in case weird key combos open others
    let ids = editor
        .documents()
        .skip(1)
        .map(|d| d.id())
        .collect::<Vec<_>>();

    for id in ids {
        let _ = editor.close_document(id, true);
    }

    editor.focus(view_id);
}

fn reset_editor(editor: &mut Editor, compositor: &mut Compositor) {
    close_other_docs(editor);

    let id = editor.documents().next().unwrap().id();
    let _ = editor.close_document(id, true);

    editor.new_file(Action::Load);

    editor.enter_normal_mode();

    // new document has a trailing newline, so delete it (with `"_d`)
    let mut ctx = compositor::Context {
        editor,
        jobs: &mut Jobs::new(),
        scroll: None,
    };

    for key in ['"', '_', 'd'] {
        let ev = KeyEvent {
            code: KeyCode::Char(key),
            modifiers: KeyModifiers::NONE,
        };

        _ = compositor.handle_event(&Event::Key(ev), &mut ctx);
    }

    enter_insert_mode(editor);
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
enum MessageType {
    Keys = b'K',
    Text = b'T',
    Cursor = b'C',
    Reset = b'R',
}

impl TryFrom<u8> for MessageType {
    type Error = u8;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            b'K' => Ok(MessageType::Keys),
            b'T' => Ok(MessageType::Text),
            b'C' => Ok(MessageType::Cursor),
            b'R' => Ok(MessageType::Reset),
            _ => Err(value),
        }
    }
}

async fn handle_command(
    editor: &mut Editor,
    compositor: &mut Compositor,
    jobs: &mut Jobs,
    stdin: &mut BufReader<Stdin>,
    stdout: &mut BufWriter<Stdout>,
    last_cb_value: &mut Option<String>,
) -> Result<(), io::Error> {
    let mut ignored = true;

    let Ok(cmd) = MessageType::try_from(stdin.read_u8().await?) else {
        stdout.write_u8(b'E').await?;
        stdout.write_u8(0).await?;
        stdout.flush().await?;
        return Ok(());
    };

    let mut inp = Vec::new();
    loop {
        let ch = stdin.read_u8().await?;

        if ch == 0 {
            break;
        }

        inp.push(ch);
    }

    if log::max_level() >= log::Level::Trace {
        trace! {"Command: {cmd:?}"};
        trace!(
            "Input: {:?}",
            inp.iter().map(|&b| b as char).collect::<Vec<_>>()
        );
    }

    match cmd {
        MessageType::Reset => {
            reset_editor(editor, compositor);
            Ok(())
        }
        MessageType::Cursor => {
            let pos = String::from_utf8(inp)
                .expect("bad cursor pos")
                .parse::<usize>()
                .expect("bad cursor pos");

            let views = editor.tree.views_mut().collect::<Vec<_>>();

            assert!(views.len() == 1);
            let (view, _) = &views[0];
            let id = view.id;

            let doc = editor.documents_mut().next().unwrap();

            let pos = pos.min(doc.text().len_chars());
            doc.set_selection(id, Selection::point(pos));

            info!("Set cursor to {pos}");

            Ok(())
        }
        MessageType::Keys | MessageType::Text => {
            // FIXME: properly push text in so it can't hit keybindings (and will insert in normal mode)

            for ch in inp {
                let mut ctx = compositor::Context {
                    editor,
                    jobs,
                    scroll: None,
                };

                let ev = char_to_key(ch);

                trace!("Event: {ev:?}");

                if compositor.handle_event(&Event::Key(ev), &mut ctx) {
                    ignored = false;
                }
            }

            // not currently used
            _ = ignored;

            let mut message = Vec::new();
            let reg = editor.registers.read('"', editor);

            let mut clipboard = String::new();
            if let Some(mut reg) = reg {
                if let Some(val) = reg.next() {
                    if last_cb_value.as_ref().is_none_or(|s| s != val.as_ref()) {
                        clipboard = val.to_string();
                        *last_cb_value = Some(clipboard.clone());
                    }
                }
            }

            let doc = editor.documents().next().unwrap();
            let text = doc.text().to_string();

            message.extend(text.as_bytes());
            message.push(0);

            for selection in doc.selections().values() {
                for range in selection.ranges() {
                    message.extend(range.head.to_string().as_bytes());
                    message.push(0);

                    message.extend(range.anchor.to_string().as_bytes());
                    message.push(0);
                }
            }

            message.push(0);

            if !clipboard.is_empty() {
                message.push(b'Y');
                message.extend(clipboard.as_bytes());
                message.push(0);
            } else {
                message.push(b'N');
            }

            trace!("Mode: {:?}", editor.mode);
            trace!("Text: {text}");
            let mode = match editor.mode {
                helix_view::document::Mode::Normal => 'n',
                helix_view::document::Mode::Select => 's',
                helix_view::document::Mode::Insert => 'i',
            };

            message.push(mode as u8);

            if cmd == MessageType::Keys {
                stdout.write_all(&message).await?;
                stdout.flush().await?;
            }

            Ok(())
        }
    }
}

async fn main_impl() {
    events::register();

    let level = env::var("RUST_LOG").unwrap_or("WARN".into());
    let level = LevelFilter::from_str(&level).expect("Invalid log level '{level}'");
    env_logger::Builder::new()
        // .filter(None, LevelFilter::Off)
        .filter(None, level)
        // .filter_module("helix_driver", level)
        .init();

    helix_loader::initialize_config_file(None);
    helix_loader::initialize_log_file(None);

    let area = Rect {
        x: 0,
        y: 0,
        height: 100,
        width: 800,
    };

    let theme_loader = theme::Loader::new(&[]);
    let syn_loader = syntax::Loader::new(syntax::Configuration {
        language: Vec::new(),
        language_server: HashMap::new(),
    })
    .unwrap();

    let config = match Config::load_default() {
        Ok(config) => config,
        Err(ConfigLoadError::Error(err)) if err.kind() == std::io::ErrorKind::NotFound => {
            Config::default()
        }
        Err(err) => panic!("{err}"),
    };

    let config = Arc::new(ArcSwap::from_pointee(config));

    let handlers = Handlers {
        completions: null_handler(),
        signature_hints: null_handler(),
        auto_save: null_handler(),
    };

    let mut editor = Editor::new(
        area,
        Arc::new(theme_loader),
        Arc::new(ArcSwap::from_pointee(syn_loader)),
        Arc::new(Map::new(Arc::clone(&config), |config: &Config| {
            &config.editor
        })),
        handlers,
    );

    editor.new_file(Action::VerticalSplit);

    let mut jobs = Jobs::new();

    let keys = Box::new(Map::new(Arc::clone(&config), |config: &Config| {
        &config.keys
    }));

    let editor_view = Box::new(ui::EditorView::new(Keymaps::new(keys)));

    let mut stdin = BufReader::new(io::stdin());
    let mut stdout = BufWriter::new(io::stdout());

    let mut compositor = Compositor::new(area);
    compositor.push(editor_view);

    reset_editor(&mut editor, &mut compositor);

    let mut last_cb_value = None;
    loop {
        if let Err(e) = handle_command(
            &mut editor,
            &mut compositor,
            &mut jobs,
            &mut stdin,
            &mut stdout,
            &mut last_cb_value,
        )
        .await
        {
            if e.kind() == ErrorKind::UnexpectedEof {
                info!("Closing");
                return;
            }

            error!("{e}");
            continue;
        };

        close_other_docs(&mut editor);
    }
}
