#include <iostream>
#include <memory>

namespace dynamic_polymorphism {

/*----------------------------------------------------------------------------*
 * Base Pet Type
 *----------------------------------------------------------------------------*/

struct pet {
  explicit pet(std::string const & name) : name(name) {}

  // Dynamic polymorphism: callers can use pet* or pet& without knowing the
  // concrete derived type. The virtual call is resolved at run time.
  virtual void print() = 0;

protected:
  std::string name;
};

/*----------------------------------------------------------------------------*
 * Dog Type
 *----------------------------------------------------------------------------*/

struct dog : pet {
  // public types
  enum breed_t { cane_corso, neopolitan, boxer, poodle };
  enum diet_t { standard, chicken_allergy, raw };

  explicit dog(std::string const & name, breed_t breed, diet_t diet)
    : pet(name), breed(breed), diet(diet) {}

  // Overrides the base-class interface. A call through pet::print() dispatches
  // here when the object actually contains a dog.
  void print() override {
    std::cout << "Name: " << name << "\nBreed: " << breed_string(breed)
              << "\nDiet: " << diet_string(diet) << "\n"
              << std::endl;
  }

private:
  static std::string breed_string(breed_t b) {
    switch(b) {
      case cane_corso:
        return "Cane Corso";
      case neopolitan:
        return "Neopolitan";
      case boxer:
        return "Boxer";
      case poodle:
        return "Poodle";
      default:
        return "Unknown Breed";
    }
  }
  static std::string diet_string(diet_t d) {
    switch(d) {
      case standard:
        return "Standard";
      case chicken_allergy:
        return "Chicken Allergy";
      case raw:
        return "Raw";
      default:
        return "Unknown Diet";
    }
  }

  const breed_t breed;
  const diet_t diet;
};

/*----------------------------------------------------------------------------*
 * Cat Type
 *----------------------------------------------------------------------------*/

struct cat : pet {
  // public types
  enum breed_t { tabby, siamese, hairless };

  explicit cat(std::string const & name, breed_t breed, bool declawed)
    : pet(name), breed(breed), declawed(declawed) {}

  // Same run-time interface as dog::print(), but selected through the vtable
  // when the object behind a pet pointer/reference is a cat.
  void print() override {
    std::cout << "Name: " << name << "\nBreed: " << breed_string(breed)
              << "\nDeclawed: " << (declawed ? "yes" : "no") << "\n"
              << std::endl;
  }

private:
  static std::string breed_string(breed_t b) {
    switch(b) {
      case tabby:
        return "Tabby";
      case siamese:
        return "Siamese";
      case hairless:
        return "Hairless";
      default:
        return "Unknown Breed";
    }
  }

  const breed_t breed;
  const bool declawed;
};

} // namespace dynamic_polymorphism

namespace static_polymorphism {

// Static polymorphism: this function is compiled separately for each P used by
// the program. It only requires that P has a compatible print() member.
template<typename P>
void
print(P const & pet) {
  pet.print();
}

/*----------------------------------------------------------------------------*
 * Dog Attributes
 *----------------------------------------------------------------------------*/

namespace dog_attributes {

enum breed_t { cane_corso, neopolitan, boxer, poodle };

std::string
breed_string(breed_t b) {
  switch(b) {
    case cane_corso:
      return "Cane Corso";
    case neopolitan:
      return "Neopolitan";
    case boxer:
      return "Boxer";
    case poodle:
      return "Poodle";
    default:
      return "Unknown Breed";
  }
}

enum diet_t { standard, chicken_allergy, raw };

std::string
diet_string(diet_t d) {
  switch(d) {
    case standard:
      return "Standard";
    case chicken_allergy:
      return "Chicken Allergy";
    case raw:
      return "Raw";
    default:
      return "Unknown Diet";
  }
}

} // namespace dog_attributes

/*----------------------------------------------------------------------------*
 * Dog Type
 *----------------------------------------------------------------------------*/

// The breed and diet are part of the dog type itself. For example,
// dog<cane_corso, raw> and dog<poodle, standard> are different C++ types, even
// though they share the same class template definition.
template<dog_attributes::breed_t B, dog_attributes::diet_t D>
struct dog {
  dog(std::string const & name) : name(name) {}

  // No virtual function is needed: when static_polymorphism::print() is
  // instantiated with this exact dog type, this call target is known at compile
  // time and can usually be inlined.
  void print() const {
    std::cout << "Name: " << name
              << "\nBreed: " << dog_attributes::breed_string(B)
              << "\nDiet: " << dog_attributes::diet_string(D) << "\n"
              << std::endl;
  }

private:
  const std::string name;
};

/*----------------------------------------------------------------------------*
 * Cat Attributes
 *----------------------------------------------------------------------------*/

namespace cat_attributes {

enum breed_t { tabby, siamese, hairless };

std::string
breed_string(breed_t b) {
  switch(b) {
    case tabby:
      return "Tabby";
    case siamese:
      return "Siamese";
    case hairless:
      return "Hairless";
    default:
      return "Unknown Breed";
  }
}

} // namespace cat_attributes

/*----------------------------------------------------------------------------*
 * Cat Type
 *----------------------------------------------------------------------------*/

// The declawed flag is also a template argument, so it is fixed by the static
// type rather than stored as per-object run-time state.
template<cat_attributes::breed_t B, bool D>
struct cat {
  explicit cat(std::string const & name) : name(name) {}

  // This member satisfies the same "has print()" requirement as dog, but there
  // is no shared base class tying the two types together.
  void print() const {
    std::cout << "Name: " << name
              << "\nBreed: " << cat_attributes::breed_string(B)
              << "\nDeclawed: " << (D ? "yes" : "no") << "\n"
              << std::endl;
  }

private:
  const std::string name;
};

} // namespace static_polymorphism

int
main(int argc, char ** argv) {

  {
    using namespace dynamic_polymorphism;
    std::cout << "Dynammic Polymorphism\n" << std::endl;

    // Both variables have the same static type, std::unique_ptr<pet>. The
    // concrete type is chosen at allocation time and recovered by virtual
    // dispatch when print() is called.
    std::unique_ptr<pet> alberta = std::make_unique<dog>(
      "Alberta", dog::breed_t::cane_corso, dog::diet_t::raw);
    alberta->print();

    std::unique_ptr<pet> romulus =
      std::make_unique<cat>("Romulus", cat::breed_t::siamese, false);
    romulus->print();
  }

  {
    using namespace static_polymorphism;
    std::cout << "Static Polymorphism\n" << std::endl;

    // These aliases name fully specialized types. Attribute choices are encoded
    // in the type, so changing the breed/diet/declawed values changes the type
    // that the compiler instantiates.
    using my_dog_t =
      dog<dog_attributes::breed_t::cane_corso, dog_attributes::diet_t::raw>;
    using my_cat_t = cat<cat_attributes::breed_t::siamese, false>;

    {
      my_dog_t alberta("Alberta");
      // The template argument P is deduced as my_dog_t, so the compiler emits a
      // direct call to my_dog_t::print().
      print(alberta);
    }

    {
      my_cat_t romulus("Romulus");
      // This is a different instantiation of static_polymorphism::print(), with
      // P deduced as my_cat_t.
      print(romulus);
    }
  }

  return 0;
} // main
