#include <iostream>
#include <ranges>
#include <vector>

int main(int argc, char ** argv) {

  std::vector<int> ids = { 0, 1, 2, 3, 4, 5, 6, 7 };
  std::vector<bool> owned = { true, true, true, true, true, false, false, false };
  auto info = std::views::zip(ids, owned);

  for(auto [id, own] : info) {
    std::cout << id << " " << own << std::endl;
  }

	return 0;
} // main
