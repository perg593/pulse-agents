const STRIPE_PUBLISHABLE_KEY =
  'pk_test_51SKRR1BKt9RtoSV0YgP7uZU7msNS4MqVGhID1T3Fmtpo4ZEeuKs3Ov0CYLPSiUu4SMNjPGPGJRVgQTfs9fobIaxA00wdJyhbMG';
const DEFAULT_SERVER_URL = 'http://localhost:4242';
const PAYMENT_ENDPOINT = '/stripe-demo/create-payment-intent';

const elementsContainerId = 'payment-element';
const messageContainerId = 'payment-message';
const submitButtonId = 'submit';
const spinnerId = 'spinner';
const buttonTextId = 'button-text';

let stripe;
let elements;
let clientSecret = null;

init().catch((error) => {
  console.error('Stripe checkout demo failed', error);
  setMessage(`Setup error: ${error.message}`);
});

async function init() {
  await waitForStripeScript();
  stripe = window.Stripe(STRIPE_PUBLISHABLE_KEY);

  const options = parseOptions();
  clientSecret = await createPaymentIntent(options);
  if (!clientSecret) {
    setMessage('Failed to obtain a client secret. Check the demo API server.');
    return;
  }

  elements = stripe.elements({ clientSecret });
  const paymentElement = elements.create('payment');
  paymentElement.mount(`#${elementsContainerId}`);

  const form = document.getElementById('payment-form');
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    await submitPayment(options.returnUrl);
  });

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      const params = new URLSearchParams(window.location.search);
      if (params.get('payment_status') === 'success') {
        setMessage('Payment successful! You can dismiss the Pulse survey.');
      } else if (params.get('payment_status') === 'cancelled') {
        setMessage('Payment cancelled.');
      }
    }
  });
}

async function createPaymentIntent(options) {
  toggleProcessing(true);
  try {
    const endpoint = `${options.serverUrl.replace(/\/$/, '')}${PAYMENT_ENDPOINT}`;
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        amount: options.amount,
        currency: options.currency,
        description: options.description
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`API responded with ${response.status}: ${errorText}`);
    }

    const payload = await response.json();
    if (!payload || !payload.clientSecret) {
      throw new Error('Missing clientSecret in API response');
    }

    return payload.clientSecret;
  } catch (error) {
    console.error('Failed to create PaymentIntent', error);
    setMessage(`Create PaymentIntent failed: ${error.message}`);
    return null;
  } finally {
    toggleProcessing(false);
  }
}

async function submitPayment(returnUrl) {
  toggleProcessing(true);
  setMessage('');
  try {
    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: returnUrl
      },
      redirect: 'if_required'
    });

    if (error) {
      if (error.type === 'card_error' || error.type === 'validation_error') {
        setMessage(error.message || 'Payment failed.');
      } else {
        setMessage('Unexpected error occurred.');
      }
    } else {
      setMessage('Payment processed successfully.');
    }
  } catch (error) {
    console.error('Stripe confirmPayment failed', error);
    setMessage(`Payment error: ${error.message}`);
  } finally {
    toggleProcessing(false);
  }
}

function toggleProcessing(isProcessing) {
  const submitButton = document.getElementById(submitButtonId);
  const spinner = document.getElementById(spinnerId);
  const buttonText = document.getElementById(buttonTextId);

  submitButton.disabled = isProcessing;
  spinner.hidden = !isProcessing;
  buttonText.hidden = isProcessing;
}

function setMessage(message) {
  const messageEl = document.getElementById(messageContainerId);
  if (!messageEl) return;
  if (!message) {
    messageEl.hidden = true;
    messageEl.textContent = '';
  } else {
    messageEl.textContent = message;
    messageEl.hidden = false;
  }
}

function parseOptions() {
  const params = new URLSearchParams(window.location.search);

  const serverUrl = params.get('server_url') || DEFAULT_SERVER_URL;
  const amountParam = params.get('amount');
  const amount = Number.parseInt(amountParam, 10);
  const currency = (params.get('currency') || 'usd').trim().toLowerCase();
  const description =
    params.get('description') || 'Pulse Demo Checkout (test mode, no fulfillment required)';

  const returnUrl =
    params.get('return_url') ||
    `${window.location.origin}${window.location.pathname}?payment_status=success`;

  return {
    serverUrl,
    amount: Number.isFinite(amount) && amount > 0 ? amount : 5900,
    currency: currency || 'usd',
    description,
    returnUrl
  };
}

function waitForStripeScript() {
  return new Promise((resolve, reject) => {
    if (window.Stripe) {
      resolve();
      return;
    }

    const timeout = window.setTimeout(() => {
      reject(new Error('Timed out waiting for Stripe.js to load'));
    }, 6000);

    window.addEventListener('stripejsload', () => {
      clearTimeout(timeout);
      resolve();
    });
  });
}
