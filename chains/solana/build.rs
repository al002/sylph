use std::{env, path::PathBuf};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_files = [
        "../../proto/solana/types.proto",
        "../../proto/solana/service.proto",
    ];

    let proto_dir = "../../proto";
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    tonic_build::configure()
        .file_descriptor_set_path(out_dir.join("solana_descriptor.bin"))
        .out_dir("./proto")
        .build_server(true)
        .compile_protos(&proto_files, &[proto_dir])?;

    for proto_file in proto_files {
        println!("cargo:rerun-if-changed={}", proto_file);
    }

    Ok(())
}
