package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"workstation.local/data/internal/launcher"
)

func main() {
	if len(os.Args) == 2 && os.Args[1] == "version" {
		fmt.Println("workstation-launcher protocol 1")
		return
	}
	if len(os.Args) == 2 && (os.Args[1] == "help" || os.Args[1] == "--help") {
		fmt.Println("Usage: workstation-launcher serve | version")
		return
	}
	if len(os.Args) != 2 || os.Args[1] != "serve" {
		fmt.Fprintln(os.Stderr, "workstation-launcher: use --help for supported commands")
		os.Exit(2)
	}
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		fmt.Fprintln(os.Stderr, "workstation-launcher: XDG_RUNTIME_DIR is required")
		os.Exit(1)
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if err := (launcher.Server{RuntimeDir: runtimeDir}).Serve(ctx); err != nil && !errors.Is(err, context.Canceled) {
		fmt.Fprintln(os.Stderr, "workstation-launcher:", err)
		os.Exit(1)
	}
}
