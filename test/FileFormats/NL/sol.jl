# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestNonlinearSolFiles

using Test
import MathOptInterface

const MOI = MathOptInterface
const NL = MOI.FileFormats.NL

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function _hs071()
    model = MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}())
    v = MOI.add_variables(model, 4)
    l = [1.1, 1.2, 1.3, 1.4]
    u = [5.1, 5.2, 5.3, 5.4]
    start = [2.1, 2.2, 2.3, 2.4]
    MOI.add_constraint.(model, v, MOI.GreaterThan.(l))
    MOI.add_constraint.(model, v, MOI.LessThan.(u))
    MOI.set.(model, MOI.VariablePrimalStart(), v, start)
    lb, ub = [25.0, 40.0], [Inf, 40.0]
    evaluator = MOI.Test.HS071(true)
    block_data = MOI.NLPBlockData(MOI.NLPBoundsPair.(lb, ub), evaluator, true)
    MOI.set(model, MOI.NLPBlock(), block_data)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return model, v
end

"""
    test_sol_hs071()

This function tests the model with a solution as obtained from Ipopt.
"""
function test_sol_hs071()
    model, v = _hs071()
    nl_model = NL.Model()
    index_map = MOI.copy_to(nl_model, model)
    sol = NL.SolFileResults(joinpath(@__DIR__, "data", "hs071.sol"), nl_model)
    @test MOI.get(sol, MOI.ResultCount()) == 1
    @test MOI.get(sol, MOI.RawStatusString()) ==
          "Ipopt 3.14.4: Optimal Solution Found"
    @test MOI.get(sol, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
    @test MOI.get(sol, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(sol, MOI.DualStatus()) == MOI.FEASIBLE_POINT
    @test ≈(MOI.get(sol, MOI.ObjectiveValue()), 34.4432046; atol = 1e-6)
    x_p = [1.1, 1.573552, 2.6746838, 5.4]
    for (i, vi) in enumerate(v)
        v_dest = index_map[vi]
        @test ≈(MOI.get(sol, MOI.VariablePrimal(), v_dest), x_p[i]; atol = 1e-6)
    end
    F = MOI.VariableIndex
    for (i, vi) in enumerate(v)
        ci = MOI.ConstraintIndex{F,MOI.GreaterThan{Float64}}(vi.value)
        c_dest = index_map[ci]
        if i == 1
            dual = MOI.get(sol, MOI.ConstraintDual(), c_dest)
            @test ≈(dual, 28.5907038; atol = 1e-6)
        else
            @test ≈(
                MOI.get(sol, MOI.ConstraintDual(), c_dest),
                0.0;
                atol = 1e-6,
            )
        end
        @test ≈(MOI.get(sol, MOI.ConstraintPrimal(), ci), x_p[i]; atol = 1e-6)
        ci = MOI.ConstraintIndex{F,MOI.LessThan{Float64}}(vi.value)
        c_dest = index_map[ci]
        if i == 4
            dual = MOI.get(sol, MOI.ConstraintDual(), c_dest)
            @test ≈(dual, -5.58255055; atol = 1e-6)
        else
            @test ≈(
                MOI.get(sol, MOI.ConstraintDual(), c_dest),
                0.0;
                atol = 1e-6,
            )
        end
        @test ≈(MOI.get(sol, MOI.ConstraintPrimal(), ci), x_p[i]; atol = 1e-6)
    end
    nlp_block_dual = MOI.get(sol, MOI.NLPBlockDual())
    @test ≈(nlp_block_dual, [0.1787618, 0.9850008]; atol = 1e-6)
    return
end

"""
    test_sol_hs071_max_sense()

This function tests that the duals are negated if we switch the objective sense.
"""
function test_sol_hs071_max_sense()
    model, v = _hs071()
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    nl_model = NL.Model()
    index_map = MOI.copy_to(nl_model, model)
    sol = NL.SolFileResults(joinpath(@__DIR__, "data", "hs071.sol"), nl_model)
    F = MOI.VariableIndex
    for (i, vi) in enumerate(v)
        ci = MOI.ConstraintIndex{F,MOI.GreaterThan{Float64}}(vi.value)
        c_dest = index_map[ci]
        if i == 1
            dual = MOI.get(sol, MOI.ConstraintDual(), c_dest)
            @test ≈(dual, -28.5907038; atol = 1e-6)
        else
            @test ≈(
                MOI.get(sol, MOI.ConstraintDual(), c_dest),
                0.0;
                atol = 1e-6,
            )
        end
        ci = MOI.ConstraintIndex{F,MOI.LessThan{Float64}}(vi.value)
        c_dest = index_map[ci]
        if i == 4
            dual = MOI.get(sol, MOI.ConstraintDual(), c_dest)
            @test ≈(dual, 5.58255055; atol = 1e-6)
        else
            @test ≈(
                MOI.get(sol, MOI.ConstraintDual(), c_dest),
                0.0;
                atol = 1e-6,
            )
        end
    end
    nlp_block_dual = MOI.get(sol, MOI.NLPBlockDual())
    @test ≈(nlp_block_dual, -[0.1787618, 0.9850008]; atol = 1e-6)
    return
end

function test_sol_attr_out_of_bounds()
    model, v = _hs071()
    nl_model = NL.Model()
    index_map = MOI.copy_to(nl_model, model)
    sol = NL.SolFileResults(joinpath(@__DIR__, "data", "hs071.sol"), nl_model)
    @test MOI.get(sol, MOI.PrimalStatus(2)) == MOI.NO_SOLUTION
    @test MOI.get(sol, MOI.DualStatus(2)) == MOI.NO_SOLUTION
    @test_throws MOI.ResultIndexBoundsError MOI.get(sol, MOI.ObjectiveValue(2))
    x = index_map[v[1]]
    @test_throws MOI.ResultIndexBoundsError MOI.get(
        sol,
        MOI.VariablePrimal(2),
        x,
    )
    return
end

function test_sol_infeasible()
    model, _ = _hs071()
    nl_model = NL.Model()
    _ = MOI.copy_to(nl_model, model)
    sol = NL.SolFileResults(
        joinpath(@__DIR__, "data", "hs071_infeasible.sol"),
        nl_model,
    )
    @test MOI.get(sol, MOI.TerminationStatus()) == MOI.LOCALLY_INFEASIBLE
    @test MOI.get(sol, MOI.PrimalStatus()) == MOI.UNKNOWN_RESULT_STATUS
    @test MOI.get(sol, MOI.DualStatus()) == MOI.NO_SOLUTION
    return
end

function test_statuses()
    statuses = Dict(
        (0, "Optimal Solution Found") =>
            (MOI.LOCALLY_SOLVED, MOI.FEASIBLE_POINT),
        (100, "Optimal Solution Found") =>
            (MOI.LOCALLY_SOLVED, MOI.FEASIBLE_POINT),
        (200, "Converged to a locally infeasible point.") =>
            (MOI.LOCALLY_INFEASIBLE, MOI.UNKNOWN_RESULT_STATUS),
        (300, "Model is Unbounded") =>
            (MOI.DUAL_INFEASIBLE, MOI.UNKNOWN_RESULT_STATUS),
        (400, "norm limit exceeded") =>
            (MOI.OTHER_LIMIT, MOI.UNKNOWN_RESULT_STATUS),
        (500, "Solver error.") =>
            (MOI.OTHER_ERROR, MOI.UNKNOWN_RESULT_STATUS),
        (-1, "Optimal Solution Found") =>
            (MOI.LOCALLY_SOLVED, MOI.FEASIBLE_POINT),
        (-1, "Converged to a locally infeasible point.") =>
            (MOI.LOCALLY_INFEASIBLE, MOI.UNKNOWN_RESULT_STATUS),
        (-1, "Model is Unbounded") =>
            (MOI.DUAL_INFEASIBLE, MOI.UNKNOWN_RESULT_STATUS),
        (-1, "norm limit exceeded") =>
            (MOI.OTHER_LIMIT, MOI.UNKNOWN_RESULT_STATUS),
        (-1, "Solver error.") =>
            (MOI.OTHER_ERROR, MOI.UNKNOWN_RESULT_STATUS),
        (-1, "") => (MOI.OTHER_ERROR, MOI.UNKNOWN_RESULT_STATUS),
    )
    for ((a, b), (t, p)) in statuses
        @test NL._interpret_status(a, b) == (t, p)
    end
    return
end

end

TestNonlinearSolFiles.runtests()
