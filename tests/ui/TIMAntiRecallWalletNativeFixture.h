// Exact runtime names/ABIs of the decoded Wallet module. These are test doubles,
// never compiled into the production injection library.
@interface QQWalletGrapHBAIOData : NSObject
@property(nonatomic,copy) NSString *listId;
@end
@implementation QQWalletGrapHBAIOData @end
@interface QQWalletGrapHBData : NSObject
@property(nonatomic,strong) QQWalletGrapHBAIOData *aioData;
@property(nonatomic,strong) NSDictionary *grapResultData;
@end
@implementation QQWalletGrapHBData @end
static NSUInteger timantirecall_nativeResultForwards,timantirecall_nativeBackCalls;
@interface QQWalletPreGrapHBResultViewController : UIViewController
@property(nonatomic,strong) QQWalletGrapHBData *grapHBData;
- (void)handleHBGrapResult:(NSDictionary *)result;
@end
@implementation QQWalletPreGrapHBResultViewController
- (void)handleHBGrapResult:(NSDictionary *)result {timantirecall_nativeResultForwards++;self.grapHBData.grapResultData=result;}
@end
@interface CFT_UIRedGiftCustomNavigationView : UIView
@property(nonatomic,strong) UIButton *leftButton;
@property(nonatomic,weak) id delegate;
- (void)leftButtonClick:(id)sender;
@end
@interface CFT_UIRedGiftDetailBaseViewController : UIViewController
@property(nonatomic,copy) NSString *listid;
@property(nonatomic,strong) CFT_UIRedGiftCustomNavigationView *customNavigationView;
- (void)didLeftButtonClick:(id)sender;
@end
@implementation CFT_UIRedGiftCustomNavigationView
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        _leftButton=[UIButton buttonWithType:UIButtonTypeSystem];_leftButton.frame=CGRectMake(8,0,50,50);
        [_leftButton setTitle:@"返回" forState:UIControlStateNormal];
        [_leftButton addTarget:self action:@selector(leftButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_leftButton];
    }
    return self;
}
- (void)leftButtonClick:(id)sender {[(CFT_UIRedGiftDetailBaseViewController *)self.delegate didLeftButtonClick:sender];}
@end
@implementation CFT_UIRedGiftDetailBaseViewController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    self.customNavigationView=[[CFT_UIRedGiftCustomNavigationView alloc] initWithFrame:CGRectMake(0,65,350,50)];
    self.customNavigationView.delegate=self;[self.view addSubview:self.customNavigationView];
}
- (void)didLeftButtonClick:(id)sender {
    (void)sender;timantirecall_nativeBackCalls++;
    if(self.navigationController)[self.navigationController popViewControllerAnimated:YES];
    else [self dismissViewControllerAnimated:YES completion:nil];
}
@end
