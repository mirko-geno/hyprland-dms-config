# Make distrobox use bash inside containers so it never runs an older fish
# against the shared ~/.config/fish
function distrobox --wraps distrobox
    SHELL=/bin/bash command distrobox $argv
end
