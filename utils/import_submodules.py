import sys
import pkgutil
import importlib


def import_submodules(package, skip_modules=None, recursive=True):
    """
    Import all submodules of a module, recursively, including subpackages

    Original form is from StackOverflow:
        https://stackoverflow.com/a/25562415

    Parameters
    ----------

    package : str or module name
        name of the package or the imported package to import the
        submodules from.
    skip_modules : comma separated str or None
        Comma separated string of module names to be skipped.
    recursive : bool
        Import only the top level if recursive is False.
    """
    if skip_modules is not None:
        skip_modules = skip_modules.split(',')
    if isinstance(package, str):
        package = importlib.import_module(package)
    results = {}
    for loader, name, is_pkg in pkgutil.walk_packages(package.__path__):
        full_name = package.__name__ + '.' + name
        try:
            results[full_name] = importlib.import_module(full_name)
            print(full_name)
        except ImportError:
            if name.startswith('_'):
                continue
            elif name in skip_modules:
                continue
        if recursive and is_pkg:
            results.update(import_submodules(full_name))
    return results


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise IndexError("specify a packagename to import.")
    package_name = sys.argv[1]
    if len(sys.argv) >= 3:
        skip_modules = sys.argv[2]
    else:
        skip_modules = None

    import_submodules(package_name, skip_modules)
