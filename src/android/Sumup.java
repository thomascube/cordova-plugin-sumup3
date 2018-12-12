package com.sumup.cordova.plugin;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import java.math.BigDecimal;
import org.json.JSONArray;
import org.json.JSONObject;

import com.sumup.merchant.api.SumUpAPI;
import com.sumup.merchant.api.SumUpPayment;
import com.sumup.merchant.api.SumUpState;
import com.sumup.merchant.api.SumUpLogin;
import com.sumup.merchant.Models.Merchant;
import com.sumup.merchant.Models.TransactionInfo;

public class Sumup extends CordovaPlugin {
  private static final String TAG = "SumUp";
  private static final int REQUEST_CODE_LOGIN = 1;
  private static final int REQUEST_CODE_PAYMENT = 2;
  private static final int REQUEST_CODE_SETTINGS = 3;

  private CallbackContext callback = null;
  private String affiliateKey = null;

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);
    SumUpState.init(cordova.getActivity());
    affiliateKey = this.cordova.getActivity().getString(cordova.getActivity().getResources().getIdentifier("SUMUP_API_KEY", "string", cordova.getActivity().getPackageName()));
  }

  @Override
  public boolean execute(final String action, final JSONArray args, final CallbackContext callbackContext) {
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        if (action.equals("pay")) {
          doPay(args, callbackContext);
        } else if (action.equals("prepareToPay")) {
          prepareToPay(callbackContext);
        } else if (action.equals("loginWithToken")) {
          loginWithToken(args, callbackContext);
        } else if (action.equals("login")) {
          login(callbackContext);
        } else if (action.equals("logout")) {
          logout(callbackContext);
        } else if (action.equals("settings")) {
          settings(callbackContext);
        }
      }
    });

    return true;
  }


  private void prepareToPay(final CallbackContext callbackContext) {
    SumUpAPI.prepareForCheckout();
    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, true));
  }


  private void doPay(JSONArray args, final CallbackContext callbackContext) {
    // parse mandatory args
    BigDecimal amount = null;

    try {
      amount = new BigDecimal(args.getString(0));
    } catch (Exception e) {
      callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "Can't parse amount"));
      return;
    }

    SumUpPayment.Currency currency = null;
    try {
      currency = SumUpPayment.Currency.valueOf(args.getString(1));
    } catch (Exception e) {
      callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "Can't parse currency"));
      return;
    }

    SumUpPayment.Builder payment = SumUpPayment.builder(amount, currency);

    /*** add optional args ***/

    try {
      // title
      if (args.length() > 2) {
        payment.title(args.getString(2));
      }
      // transactionID
      if (args.length() > 3) {
        payment.foreignTransactionId(args.getString(3));
      }
      // skipSuccessScreen
      if (args.length() > 4 && args.getInt(4) > 0) {
        payment.skipSuccessScreen();
      }
      // receiptEmail
      if (args.length() > 5) {
        payment.receiptEmail(args.getString(5));
      }
      // receiptPhone
      if (args.length() > 6) {
        payment.receiptSMS(args.getString(6));
      }
    } catch (Exception e) {
      Log.e(TAG, "Invalid arguments for pay command", e);
      callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "Error 0x00000: Invalid arguments: " + e.getCause()));
      return;
    }

    // open checkout activity
    callback = callbackContext;
    cordova.setActivityResultCallback(this);

    SumUpAPI.checkout(this.cordova.getActivity(), payment.build(), REQUEST_CODE_PAYMENT);
  }


  private void loginWithToken(JSONArray args, final CallbackContext callbackContext) {
    String token;
    try {
      token = args.get(0).toString();
    } catch (Exception e) {
      callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "Can't parse amount"));
      return;
    }

    callback = callbackContext;
    cordova.setActivityResultCallback(this);

    SumUpLogin sumupLogin = SumUpLogin.builder(this.affiliateKey).accessToken(token).build();
    SumUpAPI.openLoginActivity(this.cordova.getActivity(), sumupLogin, REQUEST_CODE_LOGIN);
  }


  private void login(final CallbackContext callbackContext) {
    callback = callbackContext;
    cordova.setActivityResultCallback(this);

    SumUpLogin sumupLogin = SumUpLogin.builder(this.affiliateKey).build();
    SumUpAPI.openLoginActivity(this.cordova.getActivity(), sumupLogin, REQUEST_CODE_LOGIN);
  }

  private void logout(final CallbackContext callbackContext) {
    SumUpAPI.logout();
    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, true));
  }

  private void settings(final CallbackContext callbackContext) {
    callback = callbackContext;
    cordova.setActivityResultCallback(this);

    SumUpAPI.openPaymentSettingsActivity(this.cordova.getActivity(), REQUEST_CODE_SETTINGS);
  }


  @Override
  public void onActivityResult(int requestCode, int resultCode, Intent data) {
    // no intent data given: Sumup activity has been cancelled
    if (data == null) {
      callback.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, getErrorMessage(requestCode, resultCode, "Action cancelled")));
      return;
    }

    Bundle extra = data.getExtras();
    String message = extra.getString(SumUpAPI.Response.MESSAGE);
    int code = extra.getInt(SumUpAPI.Response.RESULT_CODE);

    // send ERR plugin result
    if (code != SumUpAPI.Response.ResultCode.SUCCESSFUL) {
      // translate code into unified error codes
      callback.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, getErrorMessage(requestCode, code, message)));
      return;
    }

    // compose result object
    JSONObject res = new JSONObject();
    try {
      res.put("code", code);
      res.put("message", message);
    } catch (Exception e) {}

    if (requestCode == REQUEST_CODE_LOGIN) {
      try {
        Merchant currentMerchant = SumUpAPI.getCurrentMerchant();
        res.put("merchantCode", currentMerchant.getMerchantCode());
        res.put("merchantCurrency", currentMerchant.getCurrency().toString());
      } catch (Exception e) {
        Log.e(TAG, "Error parsing login result", e);
      }
    }

    if (requestCode == REQUEST_CODE_PAYMENT) {
      try {
        res.put("txcode", extra.getString(SumUpAPI.Response.TX_CODE));

        // get additional transaction details
        TransactionInfo info = (TransactionInfo)extra.get(SumUpAPI.Response.TX_INFO);
        res.put("amount", info.getAmount());
        res.put("currency", info.getCurrency());
        res.put("status", info.getStatus());
        res.put("payment_type", info.getPaymentType());
      } catch (Exception e) {
        Log.e(TAG, "Error parsing payment result", e);
      }
    }

    if (requestCode == REQUEST_CODE_SETTINGS) {
      // no additional result values
    }

    PluginResult result = new PluginResult(PluginResult.Status.OK, res);
    result.setKeepCallback(true);
    callback.sendPluginResult(result);
  }

  private String getErrorMessage(int requestCode, int resultCode, String message) {
    int errClass = 1;
    int errCode = 0;

    switch (requestCode) {
      case REQUEST_CODE_PAYMENT:
        errClass = 2;
        break;
      case REQUEST_CODE_SETTINGS:
        errClass = 3;
        break;
      default:
        errClass = 0;
    }

    switch (resultCode) {
      case SumUpAPI.Response.ResultCode.ERROR_ALREADY_LOGGED_IN:
        errCode = 22;
        break;
      default:
        errCode = resultCode;
    }

    return String.format("Error 0x00%d%02d: %s", errClass, errCode, message);
  }
}
