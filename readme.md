# envsubzt

`envsubst` in Zig. Takes input on stdin and prints to stdout, substituting environment variables referenced by `${NAME}`. Exits with an error instead if a referenced variable is not set.
