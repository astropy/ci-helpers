import sys
import pkgutil
import importlib


def import_submodules(package, recursive=True):
    """
    Import all submodules of a module, recursively, including subpackages

    Original form is from StackOverflow:
        https://stackoverflow.com/a/25562415

    Parameters
    ----------

    package : str or module name
        name of the package or the imported package to import the
        submodules from.
    recursive : bool
        Import only the top level if recursive is False.
    """
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
        if recursive and is_pkg:
            results.update(import_submodules(full_name))
    return results


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise IndexError("specify a packagename to import.")
    import_submodules(sys.argv[1])
