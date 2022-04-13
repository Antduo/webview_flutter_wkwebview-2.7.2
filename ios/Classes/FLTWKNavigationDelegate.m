// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTWKNavigationDelegate.h"

@implementation FLTWKNavigationDelegate {
  FlutterMethodChannel *_methodChannel;
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
  self = [super init];
  if (self) {
    _methodChannel = channel;
  }
  return self;
}

#pragma mark - WKNavigationDelegate conformance

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
  [_methodChannel invokeMethod:@"onPageStarted" arguments:@{@"url" : webView.URL.absoluteString}];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

   NSURL *url = navigationAction.request.URL;
   NSString *reqUrl = url.absoluteString;
   NSLog(@"-url---- %@",reqUrl);
   NSString *scheme = [url scheme];

   static NSString *endPayRedirectURL = nil;
   // H5微信支付完,跳回到APP
   if ([reqUrl containsString:@"nidianme.com"]) {
       self.url = @"www.nidianme.com";
   }

   if ([reqUrl containsString:@"haodf.com"]) {
       self.url = @"www.haodf.com";
   }

   if ([reqUrl containsString:@"orange1.com.cn"]) {
       self.url = @"www.orange1.com.cn";
   }


   if ([reqUrl hasPrefix:@"https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb"] && ![reqUrl hasSuffix:[NSString stringWithFormat:@"redirect_url=%@://",self.url]]) {
       decisionHandler(WKNavigationActionPolicyCancel);

       NSString *redirectUrl = nil;
       if ([reqUrl containsString:@"redirect_url="]) {
            NSRange redirectRange = [reqUrl rangeOfString:@"redirect_url"];
            endPayRedirectURL =  [reqUrl substringFromIndex:redirectRange.location+redirectRange.length+1];
            redirectUrl = [[reqUrl substringToIndex:redirectRange.location] stringByAppendingString:[NSString stringWithFormat:@"redirect_url=%@://",self.url]];
       }else {
            redirectUrl = [reqUrl stringByAppendingString:[NSString stringWithFormat:@"&redirect_url=%@://",self.url]];
       }
       NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:redirectUrl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
       newRequest.allHTTPHeaderFields = navigationAction.request.allHTTPHeaderFields;
       newRequest.URL = [NSURL URLWithString:redirectUrl];
       [webView loadRequest:newRequest];
       return;
   }

  if (!self.hasDartNavigationDelegate) {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }
  NSDictionary *arguments = @{
    @"url" : navigationAction.request.URL.absoluteString,
    @"isForMainFrame" : @(navigationAction.targetFrame.isMainFrame)
  };
  [_methodChannel invokeMethod:@"navigationRequest"
                     arguments:arguments
                        result:^(id _Nullable result) {
                          if ([result isKindOfClass:[FlutterError class]]) {
                            NSLog(@"navigationRequest has unexpectedly completed with an error, "
                                  @"allowing navigation.");
                            decisionHandler(WKNavigationActionPolicyAllow);
                            return;
                          }
                          if (result == FlutterMethodNotImplemented) {
                            NSLog(@"navigationRequest was unexepectedly not implemented: %@, "
                                  @"allowing navigation.",
                                  result);
                            decisionHandler(WKNavigationActionPolicyAllow);
                            return;
                          }
                          if (![result isKindOfClass:[NSNumber class]]) {
                            NSLog(@"navigationRequest unexpectedly returned a non boolean value: "
                                  @"%@, allowing navigation.",
                                  result);
                            decisionHandler(WKNavigationActionPolicyAllow);
                            return;
                          }
                          NSNumber *typedResult = result;
                          decisionHandler([typedResult boolValue] ? WKNavigationActionPolicyAllow
                                                                  : WKNavigationActionPolicyCancel);
                        }];
}


- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  if (!self.shouldEnableZoom) {
    NSString *source =
        @"var meta = document.createElement('meta');"
        @"meta.name = 'viewport';"
        @"meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0,"
        @"user-scalable=no';"
        @"var head = document.getElementsByTagName('head')[0];head.appendChild(meta);";

    [webView evaluateJavaScript:source completionHandler:nil];
  }

  [_methodChannel invokeMethod:@"onPageFinished" arguments:@{@"url" : webView.URL.absoluteString}];
}

+ (id)errorCodeToString:(NSUInteger)code {
  switch (code) {
    case WKErrorUnknown:
      return @"unknown";
    case WKErrorWebContentProcessTerminated:
      return @"webContentProcessTerminated";
    case WKErrorWebViewInvalidated:
      return @"webViewInvalidated";
    case WKErrorJavaScriptExceptionOccurred:
      return @"javaScriptExceptionOccurred";
    case WKErrorJavaScriptResultTypeIsUnsupported:
      return @"javaScriptResultTypeIsUnsupported";
  }

  return [NSNull null];
}

- (void)onWebResourceError:(NSError *)error {
  [_methodChannel invokeMethod:@"onWebResourceError"
                     arguments:@{
                       @"errorCode" : @(error.code),
                       @"domain" : error.domain,
                       @"description" : error.description,
                       @"errorType" : [FLTWKNavigationDelegate errorCodeToString:error.code],
                     }];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
  [self onWebResourceError:error];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  [self onWebResourceError:error];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
  NSError *contentProcessTerminatedError =
      [[NSError alloc] initWithDomain:WKErrorDomain
                                 code:WKErrorWebContentProcessTerminated
                             userInfo:nil];
  [self onWebResourceError:contentProcessTerminatedError];
}

@end
