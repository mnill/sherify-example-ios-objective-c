//
//  ViewController.m
//  example

#import "ViewController.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

@interface ViewController () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@end

@implementation ViewController
#define kProductIdentifier @"put your product id (the one that we just made in iTunesConnect) in here"
#define kSherifyUrl @"Put your sherify url from project settings."

- (void)viewDidLoad {
    [super viewDidLoad];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:kProductIdentifier]];
    productsRequest.delegate = self;
    [productsRequest start];
    [self.Button addTarget:self action:@selector(purchaseButtonClicked:) forControlEvents:UIControlEventTouchDown];
    [self checkCoinsCount];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    unsigned long count = [response.products count];
    if(count > 0) {
        NSLog(@"Products Available!");
        self.validProduct = [response.products objectAtIndex:0];
        self.Button.enabled = true;
        NSNumberFormatter *_priceFormatter = [[NSNumberFormatter alloc] init];
        [_priceFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [_priceFormatter setLocale:self.validProduct.priceLocale];
        NSString *price = [_priceFormatter stringFromNumber:self.validProduct.price];
        self.Text.text = [NSString stringWithFormat:@"Product price %@", price];
    } else {
        //this is called if your product id is not valid, this shouldn't be called unless that happens.
        NSLog(@"No products available");
    }
}

-(IBAction)purchaseButtonClicked:(id)sender
{
    if (self.Button.enabled) {
        SKPayment *payment = [SKPayment paymentWithProduct:self.validProduct];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for(SKPaymentTransaction *transaction in transactions) {
        __block SKPaymentTransaction *SKTransaction = transaction;
        //if you have multiple in app purchases in your app,
        //you can get the product identifier of this transaction
        //by using transaction.payment.productIdentifier
        //then, check the identifier against the product IDs
        //that you have defined to check which product the user
        //just purchased

        __block id _self = self;
        switch (SKTransaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"Transaction state -> Purchasing");
                //called when the user is in the process of purchasing.
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"Transaction state -> Deferred");
                break;
            case SKPaymentTransactionStatePurchased: {
            
                NSLog(@"Transaction state -> Purchased");

                //this is called when the user has successfully purchased the package (Cha-Ching!)
                 //you can add your code for what you want to happen when the user buys the purchase here, for this tutorial we use removing ads
                
                NSData* receipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
                if (!receipt) {
                    //DO NOT FINISH THE TRANSACTION ON ERROR.
                    [_self alert:@"Payment error! Please Try again later" withHandler:^(UIAlertAction * action) {}];
                } else {
                    [_self validatePayment:[receipt base64EncodedStringWithOptions:0] user:[[[UIDevice currentDevice] identifierForVendor] UUIDString] handler:^(NSString *status, NSString *transactionID) {
                            if ([status isEqualToString:@"ok"]) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [[SKPaymentQueue defaultQueue] finishTransaction:SKTransaction];
                                    [_self addCoins:100 forTransactionID:transactionID];
                                    [_self checkCoinsCount];
                                    [_self alert:@"Payment success!" withHandler:^(UIAlertAction * action) {}];
                                });
                            } else {
                            //DO NOT FINISH THE TRANSACTION ON ERROR.
                                [_self alert:@"Payment error! Please Try again later" withHandler:^(UIAlertAction * action) {}];
                            }
                    }];
                }
                break;
            }
            case SKPaymentTransactionStateRestored: {
                NSLog(@"Transaction state -> Restored");
                NSData* receipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
                //add the same code as you did from SKPaymentTransactionStatePurchased here
                if (!receipt) {
                    //DO NOT FINISH THE TRANSACTION ON ERROR.
                    [_self alert:@"Payment error! Please Try again later" withHandler:^(UIAlertAction * action) {}];
                } else {
                    [self validatePayment:[receipt base64EncodedStringWithOptions:0] user:[[[UIDevice currentDevice] identifierForVendor] UUIDString] handler:^(NSString *status, NSString   *transactionID) {
                        if ([status isEqualToString:@"ok"]) {
                            [_self addCoins:100 forTransactionID:transactionID];
                            [_self checkCoinsCount];
                            [[SKPaymentQueue defaultQueue] finishTransaction:SKTransaction];
                            [_self alert:@"Payment success" withHandler:^(UIAlertAction * action) {}];
                        } else {
                            //TODO do not finish transaction on error!
                            [_self alert:@"Payment error! Please Try again later" withHandler:^(UIAlertAction * action)             {}];
                        }
                    }];
                }
                break;
            }
            case SKPaymentTransactionStateFailed:
                //called when the transaction does not finish
                if (SKTransaction.error.code == SKErrorPaymentCancelled) {
                    NSLog(@"Transaction state -> Cancelled");
                    //the user cancelled the payment ;(
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:SKTransaction];
                break;
        }
    }
}

- (void) validatePayment: (NSString*) receipt user:(NSString*) user  handler:(void(^) (NSString* _Nullable status, NSString* _Nullable transactionID)) handler
{
    __block void (^_completionHandler)(NSString *status, NSString* _Nullable transactionID) = [handler copy];
    
    NSMutableDictionary *jsonDict = [[NSMutableDictionary alloc] init];
    [jsonDict setValue:receipt forKey:@"receipt"];
    [jsonDict setValue:user forKey:@"user"];
    
    NSError *err;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&err];

    NSLog(@"jsonRequest is %@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    
    NSURL *url = [NSURL URLWithString:kSherifyUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];

    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[jsonData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:
                                  ^(NSData *data, NSURLResponse *response, NSError *error) {
                                      NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                      if (error != nil || [httpResponse statusCode] != 200) {
                                          if (error != nil)
                                              NSLog(@"validate request error %@", [error description]);
                                          else
                                              NSLog(@"validate request status code %ld answer is %@", (long)[httpResponse statusCode], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                          
                                          //retry request
                                          [self alert:@"No network connection!" withHandler:^(UIAlertAction * action) {
                                              [self validatePayment:receipt user:user handler:_completionHandler];
                                          }];
                                      } else {
                                          NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                          NSError *e = nil;
                                          NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
                                          if (!jsonDict || e != nil) {
                                              NSLog(@"Error parsing JSON: %@", e);
                                              //retry request
                                              [self alert:@"No network connection!" withHandler:^(UIAlertAction * action) {
                                                  [self validatePayment:receipt user:user handler:_completionHandler];
                                              }];
                                          } else {
                                              NSString* status = [jsonDict valueForKey:@"status"];
                                              if ([status isEqualToString:@"ok"]) {
                                                  NSString* transactionID = [jsonDict valueForKey:@"transaction"];
                                                  _completionHandler(status, transactionID);
                                              } else {
                                                  _completionHandler(status, nil);
                                              }
                                        }
                                      }
                                  }];
    [task resume];
}



- (void) alert: (NSString*) message withHandler: (void(^)(UIAlertAction * action)) handler {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:handler];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}


- (void) addCoins: (int) coins forTransactionID:(NSString*) transactionID {
    [[NSUserDefaults standardUserDefaults] synchronize];
    BOOL isTransactionAlreadyAdded = [[[NSUserDefaults standardUserDefaults] valueForKey:transactionID] boolValue];
    if (!isTransactionAlreadyAdded) {
        long coins = [[[NSUserDefaults standardUserDefaults] valueForKey:@"coins"] integerValue];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:transactionID];
        [[NSUserDefaults standardUserDefaults] setInteger:coins+100 forKey:@"coins"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}


- (void) checkCoinsCount {
    [[NSUserDefaults standardUserDefaults] synchronize];
    long coins = [[[NSUserDefaults standardUserDefaults] valueForKey:@"coins"] integerValue];
    NSLog(@"You got %d", coins);
    self.Coins.text = [NSString stringWithFormat:@"You got %d coins", coins];
}


@end
