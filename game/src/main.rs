//! Minimal mock Windows game — reads assets from ./assets/ next to the exe.
//! Used as the real build input on Windows CI (replaces gen-minimal-pe fixture).

use std::fs;
use std::path::PathBuf;

fn main() {
    let exe = std::env::current_exe().expect("current_exe");
    let dir = exe.parent().expect("exe dir");
    let assets = dir.join("assets");

    println!("Mock Window Game");
    println!("================");
    println!("exe:    {}", exe.display());
    println!("assets: {}", assets.display());

    let config_path = assets.join("config.json");
    match fs::read_to_string(&config_path) {
        Ok(text) => println!("config.json: {} bytes", text.len()),
        Err(e) => {
            eprintln!("warn: cannot read config.json: {e}");
        }
    }

    let version_path = assets.join("version.txt");
    match fs::read_to_string(&version_path) {
        Ok(text) => {
            let tag = text.lines().next().unwrap_or("unknown");
            println!("release tag: {tag}");
        }
        Err(_) => println!("version.txt: (not injected yet)"),
    }

    let levels = assets.join("data/levels.json");
    if levels.exists() {
        println!("levels.json: ok");
    }

    println!("mock game ready");
}
