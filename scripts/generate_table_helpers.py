"""Common trusted model loading and table-module ownership for local assembly tools."""
from pathlib import Path
import importlib.util, sys
ROOT=Path(__file__).resolve().parents[1]
def load_catalog():
    spec=importlib.util.spec_from_file_location('aisports_owned_model',ROOT/'database/model/catalog.py')
    model=importlib.util.module_from_spec(spec); sys.modules[spec.name]=model; spec.loader.exec_module(model)
    return model
def module_path(table):
    return ROOT/'backend/aisports-domains'/table.domain.lower()/('aisports-table-'+table.name[4:].replace('_','-'))
