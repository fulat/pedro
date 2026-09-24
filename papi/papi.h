#pragma once

// Compatibility include for the original PAPI placeholder. New code should use
// <pedro.hpp>, <pedro/papi.hpp>, or a specific module header.
#include <pedro/papi.hpp>

namespace pedro {
    namespace papi = ::Pedro::Papi;
}
