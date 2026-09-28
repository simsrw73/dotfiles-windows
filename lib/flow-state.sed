# git clean filter for Flow Launcher settings (see .gitattributes).
# Pins values Flow rewrites as it runs, keeping the JSON valid and in
# Flow's own formatting. SearchWindowAlign is Center, so Flow recomputes
# its position; an old LastIndexTime just makes Flow reindex.
s/^(\s*"(WindowLeft|WindowTop|ActivateTimes)": )[0-9.]+/\10/
s/^(\s*"LastIndexTime": )"[^"]*"/\1"0001-01-01T00:00:00"/
