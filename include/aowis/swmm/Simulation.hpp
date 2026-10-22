#pragma once

#include <filesystem>

namespace aowis::swmm {

struct SimulationResult {
    int errorCode = 0;
    int engineVersion = 0;
};

// SWMM's global state is not reentrant. All calls made through this interface
// are serialized within the current process; separate simulation processes are
// required for truly parallel models.
SimulationResult runSimulation(const std::filesystem::path& input,
                               const std::filesystem::path& report,
                               const std::filesystem::path& binaryOutput);

int engineVersion();

}  // namespace aowis::swmm
