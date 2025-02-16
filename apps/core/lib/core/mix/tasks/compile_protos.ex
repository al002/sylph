defmodule Mix.Tasks.CompileProtos do
  use Mix.Task

  @shortdoc "Compiles protocol buffer definitions"
  def run(_) do
    Mix.shell().info("Compiling protocol buffers...")

    File.mkdir_p!("lib/proto")

    {_, 0} =
      System.cmd(
        "protoc",
        [
          "--elixir_out=plugins=grpc:./lib/proto",
          "--proto_path=../../proto",
          "ethereum/service.proto",
          "ethereum/types.proto"
        ]
      )

    {_, 0} = System.cmd("protoc",
      [
        "--elixir_out=plugins=grpc:./lib/proto",
        "--proto_path=../../proto",
        "solana/service.proto",
        "solana/types.proto"
      ]
    )

    Mix.shell().info("Protocol buffers compiled successfully!")
  end
end
