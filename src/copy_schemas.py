from pathlib import Path

import mkdocs_gen_files as mgf
from mkdocs.config.defaults import MkDocsConfig

config: MkDocsConfig = mgf.config

schema_src_dir = Path(config.config_file_path).parent / "schemas"
schema_docs_dir = "schemas"

# get schema file list
schema_files = [x for x in schema_src_dir.iterdir() if x.is_file() and x.suffix == ".json"]

for schema_file in schema_files:
    dest_path = f"{schema_docs_dir}/{schema_file.name}"
    dest_page = f"{schema_file.stem}.md"
    with mgf.open(dest_path, "wb") as dest:
        dest.write(schema_file.read_bytes())
