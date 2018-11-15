import sys
import pkgutil
import importlib


def import_submodules(package, skip_modules='', recursive=True):
    """
    Import all submodules of a module, recursively, including subpackages

    Original form is from StackOverflow:
        https://stackoverflow.com/a/25562415

    Parameters
    ----------

    package : str or module name
        name of the package or the imported package to import the
        submodules from.
    skip_modules : comma separated str
        Comma separated string of module names to be skipped.
    recursive : bool
        Import only the top level if recursive is False.
    """

    skip_modules_list = skip_modules.split(',')

    if isinstance(package, str):
        package = importlib.import_module(package)
    results = {}
    errors = []

    for loader, name, is_pkg in pkgutil.walk_packages(package.__path__):
        full_name = package.__name__ + '.' + name

        # Sometimes ``walk_packages`` pickes up fuller namespaces thus we may
        # miss skipping the modules we intended to skip
        all_names = full_name.split('.')

        name_skip = set(all_names).intersection(skip_modules_list)
        is_non_public = any((n.startswith('_') for n in (all_names[-1], name)))
        full_name_skip = any([full_name.startswith(m) for m in skip_modules_list])

        if is_non_public or full_name_skip or name_skip:
            continue
        try:
            results[full_name] = importlib.import_module(full_name)
            if recursive and is_pkg:
                result, error = import_submodules(full_name, skip_modules)
                results.update(result)
                errors.append(error)
        except ImportError as errs:
            print("Cannot import {}".format(full_name))
            errors.append(str(errs))

    return results, errors


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise IndexError("specify a packagename to import.")
    package_name = sys.argv[1]
    if len(sys.argv) >= 3:
        skip_modules = sys.argv[2]
    else:
        skip_modules = ''

    results, errors = import_submodules(package_name, skip_modules)

    if len(errors) > 0:
        raise ImportError("Cannot import from {} module(s).".format(len(errors)))
