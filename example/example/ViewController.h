//
//  ViewController.h
//  example
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *Coins;
@property (weak, nonatomic) IBOutlet UIButton *Button;
@property (weak, nonatomic) IBOutlet UILabel *Text;
@property (strong, nonatomic) SKProduct *validProduct;

@end

