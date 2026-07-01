# Static and Dynamic Polymorphism Example

This project is a small C++ example that contrasts dynamic polymorphism with
static polymorphism. Both approaches model pets and print information about a
dog and a cat, but they differ in where type selection happens.

## Code Overview

The example lives in `main.cc` and is split into two namespaces:

- `dynamic_polymorphism` uses a shared abstract base type, `pet`, with a virtual
  `print()` function. `dog` and `cat` inherit from `pet`, and callers store them
  through `std::unique_ptr<pet>`. The concrete `print()` implementation is
  selected at run time through virtual dispatch.
- `static_polymorphism` uses templates instead of a base class. The free
  `print()` function is instantiated for each concrete pet type, and attributes
  such as dog breed, dog diet, cat breed, and the cat declawed flag are encoded
  in template arguments. The compiler knows the concrete type at compile time.

The `main()` function runs both examples with similar data so the output is easy
to compare.

## Build

This project uses CMake and requires a C++20-capable compiler.

```sh
cmake -S . -B build
cmake --build build
```

## Run

After building, run the executable from the project root:

```sh
./build/test
```

The program prints one section for dynamic polymorphism and one section for
static polymorphism.
