#include <iostream>
#include <algorithm> // for std::copy_n
#include <cstddef>   // for std::size_t

// 1. Define a structural literal class
template<std::size_t N>
struct string_literal {
    char data[N] {};

    // constexpr constructor required for compile-time use
    consteval string_literal(const char (&str)[N]) {
        std::copy_n(str, N, data);
    }
    
    // Defaulted comparison operators are needed for the type to be a structural type (C++20 requirement)
    constexpr bool operator==(const string_literal& other) const = default;
};

// 2. Define a deduction guide to help the compiler deduce N
template<std::size_t N>
string_literal(const char (&)[N]) -> string_literal<N>;

// 3. Use the wrapper class as a template parameter
template<string_literal L> // 'string_literal' is the class template name, not a specific type
void Print() {
    std::cout << L.data << std::endl;
}

int main() {
    Print<"Hello, C++20!">(); // Works seamlessly
    Print<"Lello, C++20!">(); // Works seamlessly
    Print<"Another string">(); // Works with a different size string
}

