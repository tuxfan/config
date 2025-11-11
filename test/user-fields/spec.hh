#ifndef UF_SPEC_HH
#define UF_SPEC_HH

#include <flecsi/topo/unstructured/interface.hh>

#include "types.hh"

namespace spec {

template<std::size_t D, std::size_t PO>
struct policy {};

template<std::size_t D, std::size_t PO>
struct mesh_topology : policy<D, PO>,
  flecsi::topo::specialization<flecsi::topo::unstructured, mesh_topology<D, PO>> {
};

template<std::size_t D, std::size_t PO>
struct mesh {

  template<auto ... PP>
  struct accessor : flecsi::data::params_tag {
    template<typename T>
    using field_accessor = typename field<T>::template accessor<PP...>;
    using mesh_topology_accessor = typename mesh<D, PO>::template accessor<PP...>;

    accessor(mesh_topology_accessor m,
      field_accessor<int> intf,
      field_accessor<double> doublef) :
      m(m), intf(intf), doublef(doublef) {}

    auto flecsi_params() {
      return std::tie(m, intf, doublef);
    }

  private:
    mesh_topology_accessor m;
    field_accessor<int> intf;
    field_accessor<double> doublef;
  };
};

}

#endif // UF_SPEC_HH
