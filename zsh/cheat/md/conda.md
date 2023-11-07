## Conda cheatsheet

This cheatsheet was sourced from: [https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf](https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf)

## Conda basics

|Task|Command|
|:--|:--|
|Verify conda is installed, check version number|`$ conda info`|
|||
|Update condato the current version|`$ conda update conda`|
|||
|Install a package included in Anaconda|`$ conda install PACKAGENAME`|
|||
|Run a package after install, example Spyder*|`$ spyder`|
|||
|Update any installed program|`$ conda update PACKAGENAME`|
|||
|Command line help|`$ conda install --help`|

## Using environments

|Task|Command|
|:--|:--|
|Create a new environment named py35, install Python 3.5|`$ conda create --name py35 python=3.5` |
|||
|Activate the new environment to use it|`$ source activate py35`|
|||
|Get a list of all my environments, active |`$ conda env list`|
|||
|Make exact copy of an environment|`$ conda create --clone py35 --name py35-2`|
|||
|List all packages and versions installed in active environment|`$ conda list`|
|||
|List the history of each change to the current environment|`$ conda list --revisions`|
|||
|Restore environment to a previous revision|`$ conda install --revision 2`|
|||
|Save environment to a text file|`$ conda list --explicit > bio-env.txt`|
|||
|Delete an environment and everything in it|`$ conda env remove --name bio-env`|
|||
|Deactivate the current environment |`$ source deactivate`|
|||
|Create environment from a text file|`$ conda env create --file bio-env.txt `|
|||
|Stack commands: create a new environment, name it bio-env and install the biopython package|`$ conda create --name bio-env biopython`|

## Finding conda packages

|Task|Command|
|:--|:--|
|Use conda to search for a package|`$ conda search PACKAGENAME`|

## Installing and updating packages

|Task|Command|
|:--|:--|
|Install a new package (Jupyter Notebook) in the active environment|`$ conda install jupyter`|
|||
|Run an installed package (Jupyter Notebook)|`$ jupyter-notebook`|
|||
|Install a new package (toolz) in a different environment (bio-env)|`$ conda install --name bio-env toolz`|
|||
|Update a package in the current environment|`$ conda update scikit-learn`|
|||
|Install a package (boltons) from a specific channel (conda-forge)|`$ conda install --channel conda-forge boltons`|
|||
|Install a package directly from PyPI into the current active environment using pip|`$ pip install boltons`|
|||
|Remove one or more packages (toolz, boltons) from a specific environment (bio-env)|`$ conda remove --name bio-env toolz boltons`|

## Managing multiple versions of Python

|Task|Command|
|:--|:--|
|Install different version of Python in a new environment named py34 |`$ conda create --name py34 python=3.4`|
|||
|Switch to the new environment that has a different version of Python|`$ source activate py34`|
|||
|Show the locations of all versions of Python that are currently in the path|`$ which -a python`|
|||
|Show version information for the current active Python|`$ python --version`|

## Specifying version numbers

|Constraint type|Specification|Result|
|:--|:--|:--|
|Fuzzy|`numpy=1.11`|1.11.0, 1.11.1, 1.11.2, 1.11.18 etc.|
|Exact|`numpy==1.11`|1.11.0|
|Greater than or equal to|`"numpy>=1.11"`|1.11.0 or higher|
|OR|`"numpy=1.11.1|1.11.3"`|1.11.1, 1.11.3|
|AND|`"numpy>=1.8,<2"`|1.8, 1.9, not 2.0|
