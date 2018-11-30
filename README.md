# cordova-plugin-sumup3

Cordova plugin for native acces to the SumUp payment system via the SumUp SDK v3.x

This plugin permits interconnection beetween native SumUp SDK and hybrid mobile apps (cordova/phonegap).

## Platforms

* iOS 9+
* Android

## Installation

```
$ cordova plugin add cordova-plugin-sumup3 --variable SUMUP_API_KEY=<YOUR_AFFILIATION_KEY>
```

You can add your affiliation key here: https://me.sumup.com/developers
You have to add your cordova package ID in the 'Application identifiers'

## API

The plugin exposes an interface object to `cordova.SumUp` for direct interaction
with the SDK functions. See `www/sumup.js` for details about the available
functions and their arguments. All API functions are asynchronous and return a
[Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises).

## Usage Example

```js
  // perform a (mandatory) merchant login
  cordova.SumUp.login()
    .then(function(res) {
      /*
      res: {
        currencyCode: {String},
        merchantCode: {String}
      }
      */
    }).catch(function(error) {
      // handle error
    });

  // initiate payment with a SumUp card reader
  cordova.SumUp.pay(amount, currency (e.g. 'EUR'), title, transactionId)
    .then(function(res) {
      /*
      res: {
          txcode: {String} // transaction code from sumup
          amount: {Number}  // result code from sumup, more info here : https://github.com/sumup/sumup-android-sdk#1-response-fields
          currency: {String} // message from sumup
          status: {String}
        }
      */
    }.catch(function(error) {
      // handle error
    });
```

## License

[MIT License](http://ilee.mit-license.org)

## Credits

Inspired by https://github.com/Oupsla/cordova-sumup-plugin
