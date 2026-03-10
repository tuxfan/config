#include <iostream>
#include <tuple>
#include <type_traits>

// Helper to detect tuples
template<typename T>
struct is_tuple : std::false_type {};

template<typename... Ts>
struct is_tuple<std::tuple<Ts...>> : std::true_type {};


// Forward declaration
template<typename T1, typename T2, typename Func>
void visit_tuples(T1&& a, T2&& b, Func&& f);


// Iterate over tuple elements using index_sequence
template<typename T1, typename T2, typename Func, std::size_t... Is>
void visit_tuple_impl(T1&& a, T2&& b, Func&& f, std::index_sequence<Is...>)
{
    (..., visit_tuples(std::get<Is>(std::forward<T1>(a)),
                      std::get<Is>(std::forward<T2>(b)), f));
}


// Base visitor
template<typename T1, typename T2, typename Func>
void visit_tuples(T1&& a, T2&& b, Func&& f)
{
    if constexpr (is_tuple<std::decay_t<T1>>::value)
    {
        constexpr std::size_t N =
            std::tuple_size_v<std::decay_t<T1>>;

        visit_tuple_impl(
            std::forward<T1>(a),
            std::forward<T2>(b),
            std::forward<Func>(f),
            std::make_index_sequence<N>{});
    }
    else
    {
        // Leaf element
        f(std::forward<T1>(a), std::forward<T2>(b));
    }
}

template<std::size_t D, std::size_t PO>
struct action {
  static void invoke(action const & theirs) {
    std::cout << "mine: " << D << " " << PO << std::endl;
    theirs.other();
  }
  static void other() { std::cout << "HI" << std::endl; }
};

// Example usage
int main()
{
    auto a = std::make_tuple(
        std::make_tuple(action<1,2>{}, action<2,2>{}),
        std::make_tuple(action<1,3>{}, action<2,3>{})
    );
    auto b = std::make_tuple(
        std::make_tuple(action<1,2>{}, action<2,2>{}),
        std::make_tuple(action<1,3>{}, action<2,3>{})
    );

    visit_tuples(a, b, [](const auto& a, const auto& b)
    {
        a.invoke(b);
    });
}
