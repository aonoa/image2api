// Global payment-popup state. openPayment() shows the QR-scan modal for an order
// (returned by POST /pay/recharge or /pay/orders/:id/continue); the modal polls
// status and fires onPaid when the order is paid.
import { reactive } from 'vue'

export const payment = reactive({ show: false, order: null, onPaid: null })

export function openPayment(order, opts = {}) {
  payment.order = order
  payment.onPaid = typeof opts.onPaid === 'function' ? opts.onPaid : null
  payment.show = true
}

export function closePayment() {
  payment.show = false
  payment.order = null
  payment.onPaid = null
}
