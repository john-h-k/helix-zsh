use std::{any::Any, collections::HashMap, fs, sync::Arc};

use tokio::{
    io::{self, AsyncRead, AsyncReadExt, AsyncWriteExt},
    sync::mpsc::{self, Sender},
};

use arc_swap::{access::Map, ArcSwap};
use clap::Parser;
use helix_core::{syntax, Selection};
use helix_term::{
    commands,
    compositor::{self, Component, EventResult},
    config::{Config, ConfigLoadError},
    events::PostCommand,
    job::Jobs,
    keymap::{Keymaps, MappableCommand},
    ui,
};
use helix_view::{
    clipboard,
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

async fn main_impl() {
    // let args = Args::parse();

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

    let jobs = &mut Jobs::new();

    let keys = Box::new(Map::new(Arc::clone(&config), |config: &Config| {
        &config.keys
    }));
    let mut editor_view = Box::new(ui::EditorView::new(Keymaps::new(keys)));

    let mut stdin = io::stdin();
    let mut stdout = io::stdout();

    enter_insert_mode(&mut editor);

    loop {
        let mut ignored = true;

        loop {
            let ch = stdin.read_u8().await.expect("reading from stdin failed");

            if ch == 0 {
                break;
            }

            let code;
            let mut modifiers = KeyModifiers::NONE;
            match ch {
                0 => break,
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

            if ch == 10 || (code == KeyCode::Char('c') && modifiers == KeyModifiers::CONTROL) {
                let id = editor.documents().next().unwrap().id();
                let _ = editor.close_document(id, true);
                editor.new_file(Action::Load);
                enter_insert_mode(&mut editor);
                ignored = false;
            } else {
                let ev = KeyEvent { code, modifiers };

                eprintln!("{ev:?}");

                let mut ctx = compositor::Context {
                    editor: &mut editor,
                    jobs,
                    scroll: None,
                };

                if let EventResult::Consumed(_) =
                    editor_view.handle_event(&Event::Key(ev), &mut ctx)
                {
                    ignored = false;
                }
            }
        }

        if ignored {
            stdout.write_u8(b'I').await.expect("write to stdout failed");
            stdout.flush().await.unwrap();
            continue;
        }

        stdout.write_u8(b'A').await.expect("write to stdout failed");

        let reg = editor.registers.read('"', &editor);

        let mut clipboard = String::new();
        if let Some(mut reg) = reg {
            if let Some(val) = reg.next() {
                clipboard = val.to_string();
            }
        }

        let doc = editor.documents().next().unwrap();
        let text = doc.text().to_string();
        let selections = doc.selections();
        let selection = selections.iter().next().unwrap().1;

        let primary = selection.primary();
        // let cursor = primary.cursor(doc.text().into());

        eprintln!("'{text}'");

        eprintln!("{primary:?}");

        eprintln!("clipboard: '{clipboard}'");

        stdout
            .write_all(&text.as_bytes()[..text.as_bytes().len().saturating_sub(1)])
            .await
            .expect("write to stdout failed");
        stdout.write_u8(0).await.expect("write to stdout failed");

        stdout
            .write_all(primary.head.to_string().as_bytes())
            .await
            .expect("write to stdout failed");
        stdout.write_u8(0).await.expect("write to stdout failed");

        stdout
            .write_all(primary.anchor.to_string().as_bytes())
            .await
            .expect("write to stdout failed");
        stdout.write_u8(0).await.expect("write to stdout failed");

        if !clipboard.is_empty() {
            stdout.write_u8(b'Y').await.expect("write to stdout failed");
            stdout
                .write_all(clipboard.as_bytes())
                .await
                .expect("write to stdout failed");
            stdout.write_u8(0).await.expect("write to stdout failed");
        } else {
            stdout.write_u8(b'N').await.expect("write to stdout failed");
        }

        let mode = match editor.mode {
            helix_view::document::Mode::Normal => 'n',
            helix_view::document::Mode::Select => 's',
            helix_view::document::Mode::Insert => 'i',
        };

        stdout
            .write_u8(mode as u8)
            .await
            .expect("write to stdout failed");

        stdout.flush().await.unwrap();
    }
}
