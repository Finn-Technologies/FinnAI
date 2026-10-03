package com.abhiflex.finnai

import android.content.Context

/**
 * What a tap on a widget does to its state.
 *
 * Pure functions over [FinnWidgetState], so the rules (a counter never goes
 * below zero, a reset returns to the definition) are the same whatever the
 * launcher does with the views.
 */
object FinnHomeWidgetActions {
    /** The widget's "start over" control. */
    const val OP_RESET = 3
    const val OP_MINUS = 1
    const val OP_PLUS = 2

    /** Row taps are `OP_ROW + index`. */
    const val OP_ROW = 10

    const val ACTION_TAP = "com.abhiflex.finnai.WIDGET_TAP"
    const val EXTRA_OP = "finn_widget_op"

    fun apply(spec: FinnHomeWidgetSpec, state: FinnWidgetState, op: Int): FinnWidgetState {
        if (!spec.kind.interactive) return state
        if (op == OP_RESET) return FinnHomeWidgetStore.initialState(spec)
        return when (spec.kind) {
            FinnWidgetKind.COUNTER -> when (op) {
                OP_PLUS -> state.copy(value = (state.value + spec.step).coerceAtMost(MAX_VALUE))
                OP_MINUS -> state.copy(value = (state.value - spec.step).coerceAtLeast(0))
                else -> state
            }
            FinnWidgetKind.CHECKLIST -> {
                val index = op - OP_ROW
                if (index !in state.checks.indices) state
                else state.copy(
                    checks = state.checks.mapIndexed { i, done -> if (i == index) !done else done },
                )
            }
            FinnWidgetKind.TRACKER -> {
                val index = op - OP_ROW
                if (index !in state.values.indices) state
                else state.copy(
                    values = state.values.mapIndexed { i, n ->
                        if (i == index) (n + spec.step).coerceAtMost(MAX_VALUE) else n
                    },
                )
            }
            FinnWidgetKind.DISPLAY -> state
        }
    }

    /** Applies [op] to the widget's stored state and saves it. */
    fun handle(context: Context, appWidgetId: Int, op: Int) {
        val spec = FinnHomeWidgetStore.specFor(context, appWidgetId) ?: return
        val state = FinnHomeWidgetStore.stateFor(context, spec)
        val next = apply(spec, state, op)
        if (next != state) FinnHomeWidgetStore.saveState(context, spec, next)
    }

    private const val MAX_VALUE = 999_999
}
