function tsctx --argument-names requested_ctx
    argparse 'h/help' 'home=' 'l/list' 'r/rename=' 's/save' -- $argv; or return

    if ! test -z "$_flag_help"
        _tsctx_help
        return 0
    end

    if ! test -z "$_flag_home"
        set -f tsctx_home "$_flag_home"
    else
        set -f tsctx_home "$HOME/.local/share/tsctx"
    end

    if ! test -z "$_flag_list"
        _tsctx_list $tsctx_home 0
        return $status
    end

    if ! test -z "$_flag_rename"
        _tsctx_rename $tsctx_home $_flag_rename
        return $status
    end

    if ! test -z "$_flag_save"
        set -f stop_status (_tsctx_stop_tailscale); or begin
            echo $stop_status
            return 1
        end

        _tsctx_backup_tailscale $tsctx_home

        _tsctx_start_tailscale $stop_status

        return
    end

    if test (count $argv) -eq 0
        _tsctx_help
        return 0
    end

    _tsctx_list $tsctx_home 1 $requested_ctx
    if ! test $status -eq 0
        echo "ERROR: no context exists with the name \"$requested_ctx\""
        return
    end

    if test -f $tsctx_home/current
        set -f current_ctx (cat $tsctx_home/current | string trim)
    else
        set -f current_ctx "unknown_ctx"
    end

    # No-op "changing" context to current context
    if test "$current_ctx" = "$requested_ctx"
        echo "Switched to context \"$current_ctx\""
        return
    end

    # Make sure tailscale actually exists before we try anything serious
    if test ! -d /var/lib/tailscale
        echo "ERROR: Tailscale directory /var/lib/tailscale not found"
        return 1
    end

    set -f stop_status (_tsctx_stop_tailscale); or begin
        echo $stop_status
        return 1
    end
    _tsctx_backup_tailscale $tsctx_home $current_ctx

    # Destroy the old tailscale data
    sudo fish -c "rm -rf /var/lib/tailscale/*"

    sudo tar xf $tsctx_home/$requested_ctx.tar -C /var/lib/tailscale; or begin
        echo "ERROR: failed to restore tailscale archive"
        return 1
    end

    echo "$requested_ctx" > $tsctx_home/current
    echo "Switched to context \"$requested_ctx\""

    _tsctx_start_tailscale $stop_status
end

function _tsctx_help
    set help_string "\
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
        set home directory for tsctx (default $HOME/.local/share/tsctx)"

    echo $help_string
end

function _tsctx_list --argument-names tsctx_home quiet ctx_search
    set -f current_ctx (cat $tsctx_home/current | string trim)
    set -f ctx_found_exit 1

    for file in (find $tsctx_home -maxdepth 1 -type f -name '*.tar' -printf '%f\n' | string replace -r '\.[^.]+$' '')
        if test "$file" = "$ctx_search"
            set ctx_found_exit 0
        end

        if test "$file" = "$current_ctx"
            set file "* $file"
        end

        if test $quiet -eq 0
            echo "$file"
        end
    end

    return $ctx_found_exit
end

function _tsctx_rename --argument-names tsctx_home new_ctx_name
    if test -f $tsctx_home/current
        set -f old_ctx_name (cat $tsctx_home/current | string trim)

        if test "$old_ctx_name" = "$new_ctx_name"
            echo "Context name already set to \"$new_ctx_name\""
            return
        end

        echo "Context \"$old_ctx_name\" renamed to \"$new_ctx_name\""            
    else
        echo "Context saved as \"$new_ctx_name\""            
    end

    echo "$new_ctx_name" > $tsctx_home/current
    mv "$tsctx_home/$old_ctx_name.tar" "$tsctx_home/$new_ctx_name.tar"
end

function _tsctx_stop_tailscale
    # Check and save current tailscale status
    tailscale status > /dev/null 2>&1
    set -f ts_status $status

    # Stop tailscale before messing with the files
    sudo tailscale down > /dev/null 2>&1; or begin
        echo "ERROR: failed to stop tailscale"
        return 1
    end

    sudo systemctl stop tailscaled > /dev/null 2>&1; or begin
        echo "ERROR: failed to stop tailscaled"
        return 1
    end

    if test $ts_status -eq 0
        echo "0"
    else
        echo "1"
    end
end

function _tsctx_start_tailscale --argument-names ts_status
    sudo systemctl start tailscaled > /dev/null 2>&1; or begin
        echo "ERROR: failed to start tailscaled"
        return 1
    end

    if test "$ts_status" = "0"
        sudo tailscale up
    end
end

function _tsctx_backup_tailscale --argument-names tsctx_home current_ctx
    if ! test -d "$tsctx_home"
        mkdir "$tsctx_home"; or return 1
    end

    if test -z "$current_ctx"
        read -P "context name: " current_ctx
        echo "$current_ctx" > $tsctx_home/current
    end

    # Create a backup of the previous archive with this name
    if test -f "$tsctx_home/$current_ctx.tar"
        mv "$tsctx_home/$current_ctx.tar" "$tsctx_home/$current_ctx.tar.1"; or begin
            echo "ERROR: failed to backup tailscale archive"
            return 1
        end
    end

    # Create the new backup. Be extra careful to abort if this does not work
    sudo tar cf "$tsctx_home/$current_ctx.tar" -C /var/lib/tailscale .; or begin
        echo "ERROR: failed to create tailscale archive"
        sudo rm -f "$tsctx_home/$current_ctx.tar"
        mv "$tsctx_home/$current_ctx.tar.1" "$tsctx_home/$current_ctx.tar"
        return 1
    end

    sudo chown $USER:$USER "$tsctx_home/$current_ctx.tar"

    return $status
end