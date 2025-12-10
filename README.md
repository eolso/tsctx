# tsctx

Utility for switching tailscale "contexts", enabling multiple account usage on linux.

```
Context switcher linux cli for tailscale.

USAGE
  tsctx [flags] [context]

FLAGS
  --help, -h
        show help
  --save, -s
        save current tailscale config
  --list, -l
        list available contexts
  --rename, -r
        rename current context
  --home
        set home directory for tsctx (default $HOME/.local/share/tsctx)
```

To get started, save your current context with `tsctx -s` then proceed to logout and login to other account(s). When switching between tracked accounts, `tsctx` will automatically save again before switching.