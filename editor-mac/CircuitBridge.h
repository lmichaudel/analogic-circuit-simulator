#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int pin_id;             // comp_id * 10 + pin_index
    const char* net_name;   // e.g. "0", "n1", "n2"
    double voltage;
} PinVoltageResult;

typedef struct {
    const char* comp_label; // e.g. "R1", "V1"
    double current;
} CompCurrentResult;

typedef struct {
    int success;
    double solve_time_ms;
    const char* error_message;

    int num_pin_voltages;
    PinVoltageResult* pin_voltages;

    int num_comp_currents;
    CompCurrentResult* comp_currents;
} SimulationResultC;

SimulationResultC* simulate_circuit_str(const char* circuit_str, int solver_method);
SimulationResultC* simulate_circuit_file(const char* file_path, int solver_method);
void free_simulation_result(SimulationResultC* res);

#ifdef __cplusplus
}
#endif
