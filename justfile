# enable unstable features, needed for which() and home_dir()
set unstable
# use bash, not sh
set script-interpreter := ["bash", "-euo", "pipefail"]

# default to listing available actions
default:
    just --list

# configuration
ha_extn_repo_url := 'https://github.com/keesschollaart81/vscode-home-assistant.git'

# computed vars
git_branch := shell('git rev-parse --abbrev-ref HEAD')
schema_dir := join(justfile_dir(), 'schemas')

ha_extn_repo := join(justfile_dir(), 'vscode-home-assistant')
ha_extn_package_path := join(ha_extn_repo, 'src', 'language-service')
ha_extn_schema_path := join(ha_extn_package_path, 'src', 'schemas', 'json')

# check for act, install if missing
@install-act:
    if [[ -z "{{ which('act') }}" ]]; then \
        echo "Installing act..."; \
        curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b "{{ executable_directory() }}"; \
    fi
    echo {{ if is_dependency() == "true" { "-n ''" } else { "found act at " + which('act') } }}

# clone or update the vscode-home-assistant extension repo
@fetch-extension:
    echo "Cloning or updating vscode-home-assistant extension repo..."
    if [[ ! -d "{{ ha_extn_repo }}/.git" ]]; then \
        git clone "{{ ha_extn_repo_url }}" "{{ ha_extn_repo }}"; \
    else \
        git -C "{{ ha_extn_repo }}" pull -q; \
    fi

# build the JSON schemas
compile-extension: fetch-extension
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Compiling vscode-home-assistant extension..."
    cd "{{ ha_extn_package_path }}"
    npm ci --no-audit --no-fund
    npm run compile
    ls --almost-all --human-readable --numeric-uid-gid src/schemas/json

# copy schemas from the extension repo to our schemas/ folder and format them
build-schemas: compile-extension
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building JSON schemas..."
    mkdir -p "{{ schema_dir }}"
    cp -f {{ ha_extn_package_path }}/src/schemas/json/*.json "{{ schema_dir }}/"
    echo "Formatting JSON schemas:"
    declare -a schema_files
    for schema in "{{ schema_dir }}"/*.json; do
        schema_filename=$(basename ${schema})
        schema_files+=("$schema_filename")
        echo "  - ${schema_filename}"
        jq . "$schema" | sponge "$schema"
    done
    # write out schema list for index.md generation
    echo "Writing schema list..."
    jq -n '{schemas: $ARGS.positional}' \
        --args "${schema_files[@]}" > "{{ justfile_dir() }}/src/schema-list.json"
    echo "Schema list written to src/schema-list.json"

build-docs:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building documentation..."
    mkdir -p docs
    rm -f docs/index.md
    jinja -d  src/schema-list.json src/index.md.j2 > docs/index.md
    echo "Documentation built at src/index.md"


# commit and push the updated schemas
commit-changes: build-schemas
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking for changes to commit..."

    # ensure we're on main branch
    if [[ "{{ git_branch }}" != "main" ]]; then
        git checkout main
    fi

    # ensure up to date with remote main, fast-forward only, stashing any local changes
    if [[ -n "$(git status --porcelain)" ]]; then
        git stash -q
        git pull --ff-only origin main
        git stash -q pop || true
    else
    # add changed schema files
    git add "{{ schema_dir }}"

    # commit if there are changes
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Changes detected, committing..."
        # get the revision of the extension we built from
        ext_rev=$(git -C "{{ ha_extn_repo }}" rev-parse --short HEAD)
        # commit with appropriate message
        git commit -m "ci: Update schema files" \
            -m "Schemas built from {{ ha_extn_repo_url }} at revision ${ext_rev}" \
            -m "Upstream tree: {{ ha_extn_repo_url }}/tree/${ext_rev}"

        git push -u origin main
    else
        echo "No changes to commit."
    fi

# uses `act` to run the github workflows locally
pages-build: install-act
    @echo "running build via act..."
    #@act on:repository_dispatch -j build

pages-deploy: build-schemas
    @echo "running deployment via act..."
    #@act on:repository_dispatch -j pages-deploy
