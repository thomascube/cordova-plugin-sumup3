'use strict';

var PLUGIN_NAME = 'Sumup';

var Sumup = function() {
  this._isLoggedIn = false;
  this._tokenExpiresTimer = null;
};

var wrapError = function(err) {
  var error = new Error(err);
  // parse error code
  if (String(err).match(/Error 0x00+([1-9]\d+)/)) {
    error.code = parseInt(RegExp.$1);
  }
  return error;
};

/**
 * Initiate payment via the Sumup card reader terminnal
 *
 * This will open a modal view guiding through the payment process
 *
 * @param {Number} amount The amount to pay
 * @param {String} currencyCode The currency code (e.g. EUR, CHF, USD)
 * @param {String} title Transaction title (to be shown in history and on receipts)
 * @param {String} transactionID Foreign transaction identifier for referencing (optional)
 * @param {Boolean} skipSuccessScreen Whether to skip the paymetn success screen. This is where one send a receipt to the customer (default = false)
 * @param {String} receiptEmail Customer's e-mail address for sending a receipt to (optional, Android only)
 * @param {String} receiptPhone Customer's mobile phone number for sending an SMS receipt to (optional, Android only)
 * @return {Promise} eventually resolving with transaction result or rejecting if aborted or failed
 */
Sumup.prototype.pay = function(amount, currencyCode, title, transactionID, skipSuccessScreen, receiptEmail, receiptPhone) {
  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'pay', [String(amount), currencyCode, title, transactionID, skipSuccessScreen ? 1 : 0, receiptEmail, receiptPhone]);
  }).catch(function(err) {
    if (err.code === 205) {
      this.logout();  // force (re-)login for next transaction
    }
    return Promise.reject(err);
  }.bind(this));
};

/**
 * Initiate payment with an OAuth access token 
 *
 * @return {Promise}
 * @see loginWithToken()
 * @see pay()
 */
Sumup.prototype.payWithToken = function(token, amount, currencyCode, title, transactionID, skipSuccessScreen, receiptEmail, receiptPhone) {
  this.loginWithToken(token)
    .then(function() {
      return this.pay(amount, currencyCode, title, transactionID, skipSuccessScreen, receiptEmail, receiptPhone);
    });
};

/**
 * Can be called in advance when a checkout is imminent and a user is logged in.
 *
 * Use this method to let the SDK know that the user is most likely starting a checkout attempt soon.
 * This allows the SDK to take appropriate measures, like attempting to wake a connected card terminal.
 *
 * @return {Promise}
 */
Sumup.prototype.prepareToPay = function() {
  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'preparePay', []);
  });
};

/**
 * Logs in a merchant with an access token acquired via OAuth
 *
 * @return {Promise} eventually resolving with an {Object} providing merchant info
 */
Sumup.prototype.loginWithToken = function(token) {
  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'loginWithToken', [token]);
  }).catch(function(err) {
    // catch "Merchant already logged in" errors
    if (err.code === 22) {
      return Promise.resolve({resume: true});
    }
    this._isLoggedIn = false;
    return Promise.reject(err);
  }.bind(this)).then(function(res) {
    this._isLoggedIn = true;

    // force logout after 45 minutes to avoid token expiration errors
    if (!res.resume) {
      this._tokenExpiresTimer = setTimeout(function() {
        this.logout();
      }.bind(this), 2700 * 1000);
    }
    return res;
  }.bind(this));
};

/**
 * Presents the Sumup merchant login screen modally
 *
 * @return {Promise} eventually resolving with an {Object} providing merchant info
 */
Sumup.prototype.login = function() {
  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'login', []);
  }).then(function(res) {
    this._isLoggedIn = true;
    return res;
  }.bind(this));
};

/**
 * Performs a logout of the current merchant and resets the remembered password.
 *
 * @return {Promise} 
 */
Sumup.prototype.logout = function() {
  if (this._tokenExpiresTimer) {
    clearTimeout(this._tokenExpiresTimer);
    this._tokenExpiresTimer = null;
  }

  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'logout', []);
  }).then(function(res) {
    this._isLoggedIn = false;
    return res;
  }.bind(this));
};


/**
 * Checks if the SDK has a current merchant login
 *
 * @return {Promise} resolves if positive, rejects otherwise
 */
Sumup.prototype.isLoggedIn = function() {
  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'isLoggedIn', []);
  }).then(function(res) {
    this._isLoggedIn = res;
    return res ? Promise.resolve(true) : Promise.reject(new Error('Not logged in'));
  }.bind(this));
};

/**
 * Presenting checkout preferences as modal view
 *
 * Allows the current merchant to configure the checkout options and
 * change the card terminal. Merchants can also set up the terminal when applicable.
 * Can only be called when a merchant is logged in and checkout is not in progress.
 *
 * @return {Promise} 
 */
Sumup.prototype.settings = function() {
  return new Promise(function(resolve, reject) {
    cordova.exec(resolve, function(err){ reject(wrapError(err)); }, PLUGIN_NAME, 'settings', []);
  });
};

// create and register singleton instance
var instance = new Sumup();

module.exports = instance;
