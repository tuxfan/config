#ifndef HYDRO_TYPES_HH
#define HYDRO_TYPES_HH

#include <array>
#include <cstdlib>
#include <cstddef>
#include <cassert>
#include <iostream>
#include <span>

namespace hydro {

enum shape {
  seg2,
  quad4,
  hex8
};

enum uv {
  i,
  j,
  k
};

namespace pts {

template<std::size_t PO>
struct equidistant {
  static auto coord(std::size_t idx) {
    assert(idx <= PO);
    return PO == 0 ? 0.5 : double(idx) / PO;
  }
};

template<std::size_t PO>
struct gauss_lobatto {
};

template<>
struct gauss_lobatto<0> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.5;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<1> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<2> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.5;
      case 2:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<3> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.276393202250021;
      case 2:
        return 0.723606797749979;
      case 3:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<4> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.172673164646011;
      case 2:
        return 0.5;
      case 3:
        return 0.827326835353989;
      case 4:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<5> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.117472338035268;
      case 2:
        return 0.357384241759677;
      case 3:
        return 0.642615758240323;
      case 4:
        return 0.882527661964732;
      case 5:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<6> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.0848880518607165;
      case 2:
        return 0.265575603264643;
      case 3:
        return 0.5;
      case 4:
        return 0.734424396735357;
      case 5:
        return 0.915111948139284;
      case 6:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<7> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.0641299257451967;
      case 2:
        return 0.204149909283429;
      case 3:
        return 0.395350391048761;
      case 4:
        return 0.604649608951239;
      case 5:
        return 0.795850090716571;
      case 6:
        return 0.935870074254803;
      case 7:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

template<>
struct gauss_lobatto<8> {
  static auto coord(std::size_t idx) {
    switch(idx) {
      case 0:
        return 0.0;
      case 1:
        return 0.0501210022942699;
      case 2:
        return 0.161406860244631;
      case 3:
        return 0.318441268086911;
      case 4:
        return 0.5;
      case 5:
        return 0.681558731913089;
      case 6:
        return 0.838593139755369;
      case 7:
        return 0.949878997705730;
      case 8:
        return 1.0;
      default:
        std::cerr << "invalid index" << std::endl;
        std::abort();
    }
  }
};

} // namespace pts

/*-----------------------------------------------------------------------------*
  Primary template.
 *-----------------------------------------------------------------------------*/

// CE = continuous or discontinuous
template<shape S, std::size_t PO, template<std::size_t> typename B, bool CE>
class reference_element
{
};

template<shape S, std::size_t PO, template<std::size_t> typename B>
using kinematic_reference = reference_element<S, PO, B, true>;
template<shape S, std::size_t PO, template<std::size_t> typename B>
using thermodynamic_reference = reference_element<S, PO, B, false>;

/*-----------------------------------------------------------------------------*
  1D: seg2 specialization.
 *-----------------------------------------------------------------------------*/

// Gerneral case
template<std::size_t PO, template<std::size_t> typename B>
class reference_element<shape::seg2, PO, B, true>
{
  static constexpr std::size_t DOFS1 = PO + 1; /* dofs in one axis */
  static constexpr std::size_t ENTDOFS1 = PO - 1; /* entity dofs in one axis */

  std::array<double, 1> coords_[DOFS1];
  std::size_t ids_[DOFS1];
  static constexpr std::size_t vids_[2] = {0, 1};
  std::size_t cids_[ENTDOFS1];

  template<std::size_t... II>
  void init(std::index_sequence<II...>) {
    (([&] {
      if constexpr(II == 0) { /* vertex 0 */
        ids_[0] = 0;
        coords_[0][uv::i] = B<PO>::coord(0);
      }
      else if constexpr(II == PO) { /* vertex 1 */
        ids_[1] = 1;
        coords_[1][uv::i] = B<PO>::coord(PO);
      }
      else { /* cells */
        ids_[II + 1] = II + 1;
        cids_[II - 1] = II + 1;
        coords_[II + 1][uv::i] = B<PO>::coord(II);
      }
      return true;
    }()),
      ...);
  }

public:
  reference_element() {
    init(std::make_integer_sequence<std::size_t, DOFS1>{});
  }
  auto dofs() const {
    return std::span{ids_};
  }
  auto vdofs() const {
    return std::span{vids_};
  }
  auto vdof(std::size_t idx) {
    assert(idx < 2);
    return idx;
  }
  auto cdofs() const {
    return std::span{cids_};
  }
  auto const & coords() const {
    return coords_;
  }
};

template<std::size_t PO, template<std::size_t> typename B>
class reference_element<shape::seg2, PO, B, false>
{
  static constexpr std::size_t DOFS = PO + 1; /* total dofs */
  std::array<double, 1> coords_[DOFS];
  std::size_t ids_[DOFS];

  template<std::size_t... II>
  void init(std::index_sequence<II...>) {
    (([&] {
      ids_[II] = II;
      coords_[II][uv::i] = B<PO>::coord(II);
      return true;
    }()),
      ...);
  }

public:
  reference_element() {
    init(std::make_integer_sequence<std::size_t, DOFS>{});
  }
  auto dofs() const {
    return std::span{ids_};
  }
  auto const & coords() const {
    return coords_;
  }
};

// Piecewise linear.
template<template<std::size_t> typename B>
class reference_element<shape::seg2, 1, B, true>
{
  std::array<double, 1> coords_[2] = {B<1>::coord(0), B<1>::coord(1)};
  std::size_t ids_[2] = {0, 1};

public:
  reference_element() {}
  auto dofs() const {
    return std::span{ids_};
  }
  auto vdofs() const {
    return std::span{ids_};
  }
  auto vdof(std::size_t idx) {
    assert(idx < 2);
    return idx == 0 ? ids_[0] : ids_[1];
  }
  auto cdofs() const {
    return std::span<std::size_t>();
  }
  auto const & coords() const {
    return coords_;
  }
};

/*-----------------------------------------------------------------------------*
  2D: quad4 specialization.
 *-----------------------------------------------------------------------------*/

// General case.
template<std::size_t PO, template<std::size_t> typename B>
class reference_element<shape::quad4, PO, B, true>
{
  static constexpr std::size_t DOFS1 = PO + 1; /* dofs in one axis */
  static constexpr std::size_t ENTDOFS1 = PO - 1; /* entity dofs in one axis */
  // Vertex ordering is counter-clockwise:
  // V0: (0, 0)
  // V1: (1, 0)
  // V2: (1, 1)
  // V3: (0, 1)
  // Edges are clockwise after vertices.
  // Cell is after edges.
  static constexpr std::size_t VOFF[4] = {0, PO, DOFS1 * DOFS1 - 1, PO * DOFS1};
  static constexpr std::size_t EOFF[5] = {4,
    4 + ENTDOFS1,
    4 + 2 * ENTDOFS1,
    4 + 3 * ENTDOFS1,
    4 + 4 * ENTDOFS1 /* Cell offset for inverted edges */};
  static constexpr std::size_t C_OFF = 4 + 4 * ENTDOFS1;

  std::size_t ids_[DOFS1 * DOFS1];
  std::array<double, 2> coords_[DOFS1 * DOFS1];
  static constexpr std::size_t vids_[4] = {0, 1, 2, 3};
  std::size_t eids_[4][ENTDOFS1];
  std::size_t cids_[ENTDOFS1 * ENTDOFS1];

  template<std::size_t... JJ, std::size_t... II>
  void init(std::index_sequence<JJ...>, std::index_sequence<II...>) {
    std::size_t edof[4] = {0, 0, 0, 0};
    std::size_t cdof{0};
    (([&] {
      constexpr auto jj = JJ;
      (([&] {
        // Offset follows natural ordering.
        constexpr auto offset = jj * DOFS1 + II;
        auto const ic{B<PO>::coord(II)};
        auto const jc{B<PO>::coord(jj)};

        auto set_vertex = [&](std::size_t v) {
          ids_[v] = v;
          coords_[v][uv::i] = ic;
          coords_[v][uv::j] = jc;
        };

        // Offset is mapped to MFEM ordering for each entity type.
        if constexpr(offset == VOFF[0]) {
          set_vertex(0);
        }
        else if constexpr(offset == VOFF[1]) {
          set_vertex(1);
        }
        else if constexpr(offset == VOFF[2]) {
          set_vertex(2);
        }
        else if constexpr(offset == VOFF[3]) {
          set_vertex(3);
        }
        else {
          auto set_edge = [&](std::size_t e, bool invert = false) {
            auto const id{
              invert ? EOFF[e + 1] - (edof[e] + 1) : EOFF[e] + edof[e]};
            ids_[id] = id;
            eids_[e][edof[e]] = id;
            coords_[id][uv::i] = ic;
            coords_[id][uv::j] = jc;
            ++edof[e];
          };

          // Edge 0
          if constexpr(jj == 0 && II > 0 && II < PO) {
            set_edge(0);
          }
          // Edge 1
          if constexpr(jj > 0 && jj < PO && II == PO) {
            set_edge(1);
          }
          // Edge 2
          if constexpr(jj == PO && II > 0 && II < PO) {
            set_edge(2, true);
          }
          // Edge 3
          if constexpr(jj > 0 && jj < PO && II == 0) {
            set_edge(3, true);
          }

          // Cell
          if constexpr((jj > 0 && jj < PO) && (II > 0 && II < PO)) {
            std::size_t const id{C_OFF + cdof};
            ids_[id] = id;
            cids_[cdof] = id;
            coords_[id][uv::i] = ic;
            coords_[id][uv::j] = jc;
            ++cdof;
          }
        }
        return true;
      }()),
        ...);
      return true;
    }()),
      ...);
  }

public:
  reference_element() {
    init(std::make_integer_sequence<std::size_t, DOFS1>{},
      std::make_integer_sequence<std::size_t, DOFS1>{});
  }
  auto dofs() const {
    return std::span{ids_};
  }
  auto vdofs() const {
    return std::span{vids_};
  }
  auto vdof(std::size_t idx) {
    assert(idx < 4);
    return vids_[idx];
  }
  auto edofs(std::size_t e) const {
    assert(e < 4);
    return std::span{eids_[e]};
  }
  auto cdofs() const {
    return std::span{cids_};
  }
  auto const & coords() const {
    return coords_;
  }
};

template<std::size_t PO, template<std::size_t> typename B>
class reference_element<shape::quad4, PO, B, false>
{
  static constexpr std::size_t DOFS1 = PO + 1; /* dofs in one axis */
  std::array<double, 2> coords_[DOFS1 * DOFS1];
  std::size_t ids_[DOFS1 * DOFS1];

  template<std::size_t... JJ, std::size_t... II>
  void init(std::index_sequence<JJ...>, std::index_sequence<II...>) {
    (([&] {
      constexpr auto jj = JJ;
      (([&] {
        const auto id = jj * (DOFS1) + II;
        ids_[id] = id;
        coords_[id][uv::i] = B<PO>::coord(II);
        coords_[id][uv::j] = B<PO>::coord(jj);
        return true;
      }()),
        ...);
      return true;
    }()),
      ...);
  }

public:
  reference_element() {
    init(std::make_integer_sequence<std::size_t, DOFS1>{},
      std::make_integer_sequence<std::size_t, DOFS1>{});
  }
  auto dofs() const {
    return std::span{ids_};
  }
  auto const & coords() const {
    return coords_;
  }
};

// Piecewise linear.
template<template<std::size_t> typename B>
class reference_element<shape::quad4, 1, B, true>
{
  std::array<double, 2> coords_[4]{
    {B<1>::coord(0), B<1>::coord(0)},
    {B<1>::coord(1), B<1>::coord(0)},
    {B<1>::coord(1), B<1>::coord(1)},
    {B<1>::coord(0), B<1>::coord(1)},
  };
  std::size_t ids_[4] = {0, 1, 2, 3};

public:
  auto dofs() const {
    return std::span{ids_};
  }
  auto vdofs() const {
    return std::span{ids_};
  }
  auto vdof(std::size_t idx) {
    return ids_[idx];
  }
  auto edofs(std::size_t) const {
    return std::span<std::size_t>();
  }
  auto cdofs() const {
    return std::span<std::size_t>();
  }
  auto const & coords() const {
    return coords_;
  }
};

/*-----------------------------------------------------------------------------*
  3D: hex8 specialization.
 *-----------------------------------------------------------------------------*/

// General case.
template<std::size_t PO, template<std::size_t> typename B>
class reference_element<shape::hex8, PO, B, true>
{
  static constexpr std::size_t DOFS1 = PO + 1; /* dofs in one axis */
  static constexpr std::size_t ENTDOFS1 = PO - 1; /* entinty dofs in one axis */

  std::array<double, 3> coords_[DOFS1 * DOFS1 * DOFS1];
  std::size_t ids_[DOFS1 * DOFS1 * DOFS1];
  static constexpr std::size_t VOFF[8] = {0,
    PO,
    DOFS1 * DOFS1 - 1,
    PO * DOFS1,
    PO * DOFS1 * DOFS1,
    PO * DOFS1 * DOFS1 + PO,
    (DOFS1 * DOFS1 * DOFS1) - 1,
    PO *(DOFS1 * DOFS1 + DOFS1)};
  static constexpr std::size_t EOFF[13] = {
    8,
    8 + ENTDOFS1,
    8 + 2 * ENTDOFS1,
    8 + 3 * ENTDOFS1,
    8 + 4 * ENTDOFS1,
    8 + 5 * ENTDOFS1,
    8 + 6 * ENTDOFS1,
    8 + 7 * ENTDOFS1,
    8 + 8 * ENTDOFS1,
    8 + 9 * ENTDOFS1,
    8 + 10 * ENTDOFS1,
    8 + 11 * ENTDOFS1,
    8 + 12 * ENTDOFS1 /* Face 0 offset for inverted edges */
  };
  static constexpr std::size_t FOFF0 = 8 + 12 * ENTDOFS1;
  static constexpr std::size_t FOFF[7] = {FOFF0,
    FOFF0 + ENTDOFS1 * ENTDOFS1,
    FOFF0 + 2 * ENTDOFS1 * ENTDOFS1,
    FOFF0 + 3 * ENTDOFS1 * ENTDOFS1,
    FOFF0 + 4 * ENTDOFS1 * ENTDOFS1,
    FOFF0 + 5 * ENTDOFS1 * ENTDOFS1};
  static constexpr std::size_t COFF =
    8 + 12 * ENTDOFS1 + 6 * ENTDOFS1 * ENTDOFS1;
  static constexpr std::size_t vids_[8] = {0, 1, 2, 3, 4, 5, 6, 7};
  std::size_t eids_[12][ENTDOFS1];
  std::size_t fids_[6][ENTDOFS1 * ENTDOFS1];
  std::size_t cids_[ENTDOFS1 * ENTDOFS1 * ENTDOFS1];

  enum orientation { forward, mirror, flip };

  template<std::size_t... KK, std::size_t... JJ, std::size_t... II>
  void init(std::index_sequence<KK...>,
    std::index_sequence<JJ...>,
    std::index_sequence<II...>) {
    std::size_t edof[12] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    std::size_t fdof[6] = {0, 0, 0, 0, 0, 0};
    std::size_t cdof{0};
    (([&] {
      constexpr auto kk = KK;
      (([&] {
        constexpr auto jj = JJ;
        (([&] {
          constexpr auto offset = kk * DOFS1 * DOFS1 + jj * DOFS1 + II;
          auto const ic{B<PO>::coord(II)};
          auto const jc{B<PO>::coord(jj)};
          auto const kc{B<PO>::coord(kk)};

          auto set_vertex = [&](std::size_t id) {
            ids_[id] = id;
            coords_[id][uv::i] = ic;
            coords_[id][uv::j] = jc;
            coords_[id][uv::k] = kc;
          };
          if constexpr(offset == VOFF[0]) {
            set_vertex(0);
          }
          else if constexpr(offset == VOFF[1]) {
            set_vertex(1);
          }
          else if constexpr(offset == VOFF[2]) {
            set_vertex(2);
          }
          else if constexpr(offset == VOFF[3]) {
            set_vertex(3);
          }
          else if constexpr(offset == VOFF[4]) {
            set_vertex(4);
          }
          else if constexpr(offset == VOFF[5]) {
            set_vertex(5);
          }
          else if constexpr(offset == VOFF[6]) {
            set_vertex(6);
          }
          else if constexpr(offset == VOFF[7]) {
            set_vertex(7);
          }
          else {
          }

          auto set_edge = [&](std::size_t e, bool invert = false) {
            auto const id{
              invert ? EOFF[e + 1] - (edof[e] + 1) : EOFF[e] + edof[e]};
            ids_[id] = id;
            eids_[e][edof[e]] = id;
            coords_[id][uv::i] = ic;
            coords_[id][uv::j] = jc;
            coords_[id][uv::k] = kc;
            ++edof[e];
          };

          // Edge 0
          if constexpr(kk == 0 && jj == 0 && II > 0 && II < PO) {
            set_edge(0);
          }
          // Edge 1
          if constexpr(kk == 0 && II == PO && jj > 0 && jj < PO) {
            set_edge(1);
          }
          // Edge 2
          if constexpr(kk == 0 && jj == PO && II > 0 && II < PO) {
            set_edge(2);
          }
          // Edge 3
          if constexpr(kk == 0 && II == 0 && jj > 0 && jj < PO) {
            set_edge(3);
          }
          // Edge 4
          if constexpr(kk == PO && jj == 0 && II > 0 && II < PO) {
            set_edge(4);
          }
          // Edge 5
          if constexpr(kk == PO && II == PO && jj > 0 && jj < PO) {
            set_edge(5);
          }
          // Edge 6
          if constexpr(kk == PO && jj == PO && II > 0 && II < PO) {
            set_edge(6);
          }
          // Edge 7
          if constexpr(kk == PO && II == 0 && jj > 0 && jj < PO) {
            set_edge(7);
          }
          // Edge 8
          if constexpr(jj == 0 && II == 0 && kk > 0 && kk < PO) {
            set_edge(8);
          }
          // Edge 9
          if constexpr(jj == 0 && II == PO && kk > 0 && kk < PO) {
            set_edge(9);
          }
          // Edge 10
          if constexpr(jj == PO && II == PO && kk > 0 && kk < PO) {
            set_edge(10);
          }
          // Edge 11
          if constexpr(jj == PO && II == 0 && kk > 0 && kk < PO) {
            set_edge(11);
          }

          auto set_face = [&](std::size_t f, orientation o = forward) {
            auto const i{fdof[f] % ENTDOFS1};
            auto const j{fdof[f] / ENTDOFS1};
            auto const id{o == orientation::mirror
                            ? FOFF[f] + (j * ENTDOFS1 + (ENTDOFS1 - 1 - i))
                          : o == orientation::flip
                            ? FOFF[f] + ((ENTDOFS1 - 1 - j) * ENTDOFS1 + i)
                            : FOFF[f] + fdof[f]};
            ids_[id] = id;
            fids_[f][fdof[f]] = id;
            coords_[id][uv::i] = ic;
            coords_[id][uv::j] = jc;
            coords_[id][uv::k] = kc;
            ++fdof[f];
          };

          // Face 0
          if constexpr(kk == 0 && jj > 0 && jj < PO && II > 0 && II < PO) {
            set_face(0, orientation::flip);
          }
          // Face 1
          if constexpr(kk > 0 && kk < PO && jj == 0 && II > 0 && II < PO) {
            set_face(1);
          }
          // Face 2
          if constexpr(kk > 0 && kk < PO && jj > 0 && jj < PO && II == PO) {
            set_face(2);
          }
          // Face 3
          if constexpr(kk > 0 && kk < PO && jj == PO && II > 0 && II < PO) {
            set_face(3, orientation::mirror);
          }
          // Face 4
          if constexpr(kk > 0 && kk < PO && jj > 0 && jj < PO && II == 0) {
            set_face(4, orientation::mirror);
          }
          // Face 5
          if constexpr(kk == PO && jj > 0 && jj < PO && II > 0 && II < PO) {
            set_face(5);
          }

          // Cell
          if constexpr((kk > 0 && kk < PO) && (jj > 0 && jj < PO) &&
                       (II > 0 && II < PO)) {
            auto const id{COFF + cdof};
            ids_[id] = id;
            cids_[cdof] = id;
            coords_[id][uv::i] = ic;
            coords_[id][uv::j] = jc;
            coords_[id][uv::k] = kc;
            ++cdof;
          }
          return true;
        }()),
          ...);
        return true;
      }()),
        ...);
      return true;
    }()),
      ...);
  }

public:
  reference_element() {
    init(std::make_integer_sequence<std::size_t, DOFS1>{},
      std::make_integer_sequence<std::size_t, DOFS1>{},
      std::make_integer_sequence<std::size_t, DOFS1>{});
  }
  auto dofs() const {
    return std::span{ids_};
  }
  auto vdofs() const {
    return std::span{vids_};
  }
  auto vdof(std::size_t idx) {
    assert(idx < 8);
    return vids_[idx];
  }
  auto edofs(std::size_t e) const {
    assert(e < 12);
    return std::span{eids_[e]};
  }
  auto fdofs(std::size_t f) const {
    assert(f < 6);
    return std::span{fids_[f]};
  }
  auto cdofs() const {
    return std::span{cids_};
  }
  auto const & coords() const {
    return coords_;
  }
};

template<std::size_t PO, template<std::size_t> typename B>
class reference_element<shape::hex8, PO, B, false>
{
  static constexpr std::size_t DOFS1 = PO + 1; /* dofs in one axis */
  std::array<double, 3> coords_[DOFS1 * DOFS1 * DOFS1];
  std::size_t ids_[DOFS1 * DOFS1 * DOFS1];

  template<std::size_t... KK, std::size_t... JJ, std::size_t... II>
  void init(std::index_sequence<KK...>,
    std::index_sequence<JJ...>,
    std::index_sequence<II...>) {
    (([&] {
      constexpr auto kk = KK;
      (([&] {
        constexpr auto jj = JJ;
        (([&] {
          const auto id = kk * DOFS1 * DOFS1 + jj * DOFS1 + II;
          ids_[id] = id;
          coords_[id][uv::i] = B<PO>::coord(II);
          coords_[id][uv::j] = B<PO>::coord(jj);
          coords_[id][uv::k] = B<PO>::coord(kk);
          return true;
        }()),
          ...);
        return true;
      }()),
        ...);
      return true;
    }()),
      ...);
  }

public:
  reference_element() {
    init(std::make_integer_sequence<std::size_t, DOFS1>{},
      std::make_integer_sequence<std::size_t, DOFS1>{},
      std::make_integer_sequence<std::size_t, DOFS1>{});
  }
  auto dofs() const {
    return std::span{ids_};
  }
  auto const & coords() const {
    return coords_;
  }
};

// Piecewise linear.
template<template<std::size_t> typename B>
class reference_element<shape::hex8, 1, B, true>
{
  std::array<double, 3> coords_[8]{
    {B<1>::coord(0), B<1>::coord(0), B<1>::coord(0)},
    {B<1>::coord(1), B<1>::coord(0), B<1>::coord(0)},
    {B<1>::coord(1), B<1>::coord(1), B<1>::coord(0)},
    {B<1>::coord(0), B<1>::coord(1), B<1>::coord(0)},
    {B<1>::coord(0), B<1>::coord(0), B<1>::coord(1)},
    {B<1>::coord(1), B<1>::coord(0), B<1>::coord(1)},
    {B<1>::coord(1), B<1>::coord(1), B<1>::coord(1)},
    {B<1>::coord(0), B<1>::coord(1), B<1>::coord(1)}};
  std::size_t vids_[8] = {0, 1, 2, 3, 4, 5, 6, 7};

public:
  auto dofs() const {
    return std::span{vids_};
  }
  auto vdofs() const {
    return std::span{vids_};
  }
  auto vdof(std::size_t idx) {
    assert(idx < 8);
    return vids_[idx];
  }
  auto edofs(std::size_t) const {
    return std::span<std::size_t>();
  }
  auto fdofs(std::size_t) const {
    return std::span<std::size_t>();
  }
  auto cdofs() const {
    return std::span<std::size_t>();
  }
  auto const & coords() const {
    return coords_;
  }
};

} // namespace hydro

#endif // HYDRO_TYPES_HH
