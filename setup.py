#!/usr/bin/env python3
from Cython.Build import cythonize
from setuptools import setup, Extension

with open('README.md') as f:
    long_description = f.read()

setup(
    name='archaicy',
    version='0.0.1',
    description='Wrapper for Audio Library Utilities REtooled in Cython',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/McSinyx/archaicy',
    author='Nguyễn Gia Phong',
    author_email='vn.mcsinyx@gmail.com',
    license='LGPLv3+',
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: GNU Lesser General Public License v3 or later (LGPLv3+)',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: C++',
        'Programming Language :: Cython',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3 :: Only',
        'Topic :: Multimedia :: Sound/Audio',
        'Topic :: Software Development :: Libraries',
        'Typing :: Typed'],
    keywords='openal alure hrtf',
    ext_modules=cythonize(
        Extension('archaicy', ['archaicy.pyx'],
                  include_dirs=['/usr/include/AL/'],
                  libraries=['alure2'], language='c++'),
        compiler_directives={'language_level': 3}),
    zip_safe=False)