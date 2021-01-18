from setuptools import setup
from Cython.Build import cythonize

setup(
    ext_modules = cythonize(["helloworld.pyx","queueTest.pyx"], 
    annotate=True,
    compiler_directives={'language_level' : "3"})
)
