#!/usr/bin/env python3
"""
Script to combine requirements and update pyproject.toml [project.optional-dependencies.full] group.
"""

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

try:
    import tomlkit
    from packaging.requirements import Requirement
    from packaging.specifiers import SpecifierSet
except ImportError:
    # Install dependencies with either:
    #  - uv sync
    #  - pip install -e .
    print("Error: Missing dependencies, install both with this command: uv sync", file=sys.stderr)
    sys.exit(1)


def _extract_pyproject(path: Path) -> list[str]:
    """
    Extract dependencies array from a pyproject.toml file.

    Args:
        path: Path to the pyproject.toml file

    Returns:
        List of dependency strings
    """
    try:
        with open(path, "r") as f:
            data = tomlkit.load(f)

        deps = []

        # Extract main dependencies
        if "project" in data and "dependencies" in data["project"]:
            deps.extend(data["project"]["dependencies"])

        # Extract optional dependencies from all groups
        if "project" in data and "optional-dependencies" in data["project"]:
            for group_deps in data["project"]["optional-dependencies"].values():
                deps.extend(group_deps)

        return deps
    except Exception as e:
        print(f"Warning: Failed to read {path}: {e}", file=sys.stderr)
        return []


def _extract_requirements(path: Path) -> list[str]:
    """
    Extract package names from a requirements.txt file.

    Args:
        path: Path to the requirements file

    Returns:
        List of dependency strings (each a package)
    """
    try:
        with open(path, "r") as f:
            deps = []
            for line in f:
                # Strip whitespace and comments
                line = line.strip()
                if not line or line.startswith("#"):
                    continue

                # Skip -e or --editable lines, -r or --requirement lines, and other options
                if line.startswith("-"):
                    continue

                deps.append(line)

            return deps
    except Exception as e:
        print(f"Warning: Failed to read {path}: {e}", file=sys.stderr)
        return []

def process_library(path: Path) -> list[str]:
    """
    Process a library directory to extract all dependencies from pyproject.toml
    and requirements files.

    Args:
        path: Path to the library directory

    Returns:
        List of dependency strings
    """
    if not path.exists():
        print(f"Warning: Skipping {path} submodule (does not exist)", file=sys.stderr)
        return []

    deps = []
    with os.scandir(path.as_posix()) as entry:
        for it in entry:
            # Read project files from the ComfyUI libraries
            if it.is_file() and it.name == "pyproject.toml":
                deps.extend(_extract_pyproject(Path(it.path)))
            # Read any project requirements file from the ComfyUI libraries
            # Ex.: requirements.txt, requirements.in, requirements-dev.txt, etc
            if it.is_file() and "requirements" in it.name:
                deps.extend(_extract_requirements(Path(it.path)))

    return deps


def get_specifiers(dependencies: list[str]) -> list[str]:
    """
    Use packaging to return a list of unique package names with the most
    restrictive specifiers combined.

    Example:
        Input: ["numpy>=1.24", "pandas", "numpy<2", "pandas>3.0.0"]
        Output: ["numpy>=1.24,<2", "pandas>3.0.0"]

    Args:
        dependencies: List of dependency strings with various specifiers

    Returns:
        List of unique packages with combined specifiers
    """
    # Dictionary to store package name -> combined specifiers
    pkg_specifiers: dict[str, SpecifierSet] = {}

    for dep_str in dependencies:
        try:
            # Parse the requirement using packaging
            req = Requirement(dep_str)
            pkg_name = req.name.lower()  # Normalize package name

            # Combine specifiers for the same package
            if pkg_name in pkg_specifiers:
                # Merge specifiers by combining them
                pkg_specifiers[pkg_name] &= req.specifier
            else:
                pkg_specifiers[pkg_name] = req.specifier

        except Exception as e:
            print(f"Warning: Failed to parse dependency '{dep_str}': {e}", file=sys.stderr)
            continue

    # Build the result list
    result = []
    for pkg_name, specifiers in sorted(pkg_specifiers.items()):
        if specifiers:
            result.append(f"{pkg_name}{specifiers}")
        else:
            result.append(pkg_name)

    return result

def combine_requirements(dependencies: list[str]) -> None:
    """
    Read pyproject.toml and update the [project.optional-dependencies.full] group
    with the provided dependencies.

    Args:
        dependencies: List of dependency strings to add to the 'full' group
    """
    # Get the path to pyproject.toml (assuming it's in the parent directory)
    script_dir = Path(__file__).parent
    pyproject_path = script_dir.parent / "pyproject.toml"

    # Read the pyproject.toml file
    with open(pyproject_path, "r") as f:
        data = tomlkit.load(f)

    # Ensure the structure exists
    if "project" not in data:
        data["project"] = {}

    if "optional-dependencies" not in data["project"]:
        data["project"]["optional-dependencies"] = {}

    # Update the 'full' group with the provided dependencies
    data["project"]["optional-dependencies"]["full"] = dependencies

    # Write back to the file
    with open(pyproject_path, "w") as f:
        tomlkit.dump(data, f)


def main():
    """
    Main entry point for the script.

    Usage:
        uv run -- combine_requirements.py <path_1> <path_2> ...
    """
    if len(sys.argv) < 2:
        print("Usage: python combine_requirements.py <path_1> <path_2> ...")
        print("Example: python combine_requirements.py 'libs/comfyui' 'libs/comfyui-MODULE'")
        sys.exit(1)

    libs = [Path(lib) for lib in sys.argv[1:]]
    deps = []

    # Process libraries in parallel using ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=min(len(libs), 8)) as executor:
        # Submit all library processing tasks
        future_to_lib = {executor.submit(process_library, lib): lib for lib in libs}

        # Collect results as they complete
        for future in as_completed(future_to_lib):
            lib = future_to_lib[future]
            try:
                lib_deps = future.result()
                deps.extend(lib_deps)
                print(f"Processed {lib}: found {len(lib_deps)} dependencies")
            except Exception as e:
                print(f"Error processing {lib}: {e}", file=sys.stderr)

    # Combine and deduplicate specifiers
    vers = get_specifiers(deps)

    print(f"\nTotal unique dependencies: {len(vers)}")

    # Write to pyproject.toml
    combine_requirements(vers)


if __name__ == "__main__":
    main()
