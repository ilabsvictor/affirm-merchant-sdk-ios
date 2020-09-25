//
//  AffirmCardInfoViewController.m
//  AffirmSDK
//
//  Created by Victor Zhu on 2020/9/22.
//  Copyright © 2020 Affirm, Inc. All rights reserved.
//

#import "AffirmCardInfoViewController.h"
#import "AffirmConfiguration.h"
#import "AffirmCreditCard.h"
#import "AffirmUtils.h"
#import "AffirmCardValidator.h"
#import "AffirmRequest.h"
#import "AffirmClient.h"
#import "AffirmLogger.h"
#import "AffirmActivityIndicatorView.h"

@interface AffirmCardInfoViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *logoView;
@property (weak, nonatomic) IBOutlet UIView *cardView;
@property (weak, nonatomic) IBOutlet UILabel *cardNoLabel;
@property (weak, nonatomic) IBOutlet UILabel *expiresLabel;
@property (weak, nonatomic) IBOutlet UILabel *cvvLabel;
@property (weak, nonatomic) IBOutlet UIImageView *cardLogoView;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *cardButton;
@property (nonatomic, strong) AffirmActivityIndicatorView *activityIndicatorView;

@end

@implementation AffirmCardInfoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setHidesBackButton:YES];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(cancel:)];
    self.logoView.image = [UIImage imageNamed:@"white_logo-transparent_bg" inBundle:[NSBundle resourceBundle]];
    self.cardView.layer.masksToBounds = YES;
    self.cardView.layer.cornerRadius = 16.0f;
    self.cardButton.layer.masksToBounds = YES;
    self.cardButton.layer.cornerRadius = 6.0f;
    [self setCardNo:self.creditCard.number];
    [self setExpires:self.creditCard.expiration];
    self.cvvLabel.text = self.creditCard.cvv;

    AffirmActivityIndicatorView *activityIndicatorView = [[AffirmActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    [self.view addSubview:activityIndicatorView];
    self.activityIndicatorView = activityIndicatorView;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.activityIndicatorView.center = self.view.center;
}

- (void)setCardNo:(NSString *)text
{
    AffirmBrandType type = AffirmBrandTypeUnknown;
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:self.creditCard.number];
    if (brand) { type = brand.type; }

    self.cardLogoView.image = [UIImage imageNamed:type == AffirmBrandTypeVisa ? @"visa" : @"mastercard" inBundle:[NSBundle resourceBundle]];

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: [UIFont fontWithName:AffirmFontNameAlmaMonoBold size:17], NSForegroundColorAttributeName: [UIColor whiteColor]}];
    NSArray *cardNumberFormat = [AffirmCardValidator cardNumberFormatForBrand:type];
    NSUInteger index = 0;
    for (NSNumber *segmentLength in cardNumberFormat) {
        NSUInteger segmentIndex = 0;
        for (; index < attributedString.length && segmentIndex < [segmentLength unsignedIntegerValue]; index++, segmentIndex++) {
            if (index + 1 != attributedString.length && segmentIndex + 1 == [segmentLength unsignedIntegerValue]) {
                [attributedString addAttribute:NSKernAttributeName value:@(5)
                                         range:NSMakeRange(index, 1)];
            } else {
                [attributedString addAttribute:NSKernAttributeName value:@(0)
                                         range:NSMakeRange(index, 1)];
            }
        }
    }
    self.cardNoLabel.attributedText = attributedString;
}

- (void)setExpires:(NSString *)text
{
    NSString *_text = text;
    NSString *expirationMonth = [_text substringToIndex:MIN(_text.length, 2)];
    NSString *expirationYear = _text.length < 2 ? @"" : [_text substringFromIndex:2];
    if (expirationYear) {
        expirationYear = [expirationYear stringByRemovingIllegalCharacters];
        expirationYear = [expirationYear substringToIndex:MIN(expirationYear.length, 4)];
    }

    if (expirationMonth.length == 1 && ![expirationMonth isEqualToString:@"0"] && ![expirationMonth isEqualToString:@"1"]) {
        expirationMonth = [NSString stringWithFormat:@"0%@", text];
    }

    NSMutableArray *array = [NSMutableArray array];
    if (expirationMonth && ![expirationMonth isEqualToString:@""]) {
        [array addObject:expirationMonth];
    }
    if (expirationMonth.length == 2 && expirationMonth.integerValue > 0 && expirationMonth.integerValue <= 12) {
        [array addObject:expirationYear];
    }

    _text = [array componentsJoinedByString:@"/"];
    self.expiresLabel.text = _text;
}

- (void)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelCard
{
    [self.activityIndicatorView startAnimating];
    AffirmCancelLoanRequest *request = [[AffirmCancelLoanRequest alloc] initWithPublicKey:[AffirmConfiguration sharedInstance].publicKey checkoutId:self.creditCard.creditCardId];
    [AffirmCheckoutClient send:request handler:^(id<AffirmResponseProtocol>  _Nullable response, NSError * _Nullable error) {
        if (response && [response isKindOfClass:[AffirmCancelLoanResponse class]]) {
            AffirmCancelLoanResponse *cancelResponse = (AffirmCancelLoanResponse *)response;

            UIAlertController *controller = [UIAlertController alertControllerWithTitle:nil message:cancelResponse.message preferredStyle:UIAlertControllerStyleAlert];
            [controller addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self dismissViewControllerAnimated:YES completion:nil];
            }]];
            [self presentViewController:controller animated:YES completion:nil];
            [self.activityIndicatorView stopAnimating];
        } else if (response && [response isKindOfClass:[AffirmErrorResponse class]]) {
            AffirmErrorResponse *errorResponse = (AffirmErrorResponse *)response;
            [[AffirmLogger sharedInstance] trackEvent:@"Cancel loan failed" parameters:errorResponse.dictionary];
            UIAlertController *controller = [UIAlertController alertControllerWithTitle:nil message:errorResponse.message preferredStyle:UIAlertControllerStyleAlert];
            [controller addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:controller animated:YES completion:nil];
            [self.activityIndicatorView stopAnimating];
        }
    }];
}

- (IBAction)editPressed:(id)sender
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:nil message:@"Edit amount or cancel card" preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"Edit amount" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }]];
    [controller addAction:[UIAlertAction actionWithTitle:@"Cancel card" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self cancelCard];
    }]];
    [controller addAction:[UIAlertAction actionWithTitle:@"Never mind" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (IBAction)copyCardPressed:(id)sender
{
    [[UIPasteboard generalPasteboard] setString:self.creditCard.number];
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:nil message:@"Copied" preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:controller animated:YES completion:nil];
}

@end
