import sys
import re

pkg_pat1 = re.compile(r'.+pinned spec ([^><=\[]+)=(.+) conflicts.+')
pkg_pat2 = re.compile(r'.+pinned spec ([^><=[]+)(\[.+?\]) conflicts.+')

spec_conflicts = sys.argv[1]

if len(sys.argv) == 3:
    # We got the conda command in one shot
    original_args = sys.argv[2].split(" ")
else:
    # The arguments were split by the shell
    original_args = sys.argv[2:]

# Just crash if the command wasn't actually conda install
assert original_args[0] == 'conda'
assert original_args[1] == 'install'

with open(spec_conflicts) as f:
    lines = f.readlines()

versions = dict()

for line in lines:
    # Packages with overriden specs will match either pattern 1 or 2
    match = pkg_pat1.match(line)
    if not match:
        match = pkg_pat2.match(line)

    if match:
        package = match.group(1)
        versions[package] = "=" + match.group(2)

new_args = []

for arg in original_args:
    if arg in versions:
        # Add a version spec
        pkg_version = versions[arg]
        new_args.append(arg + pkg_version)
    else:
        new_args.append(arg)

# Our "return" value is a new command with pinned specs
print(" ".join(new_args))
