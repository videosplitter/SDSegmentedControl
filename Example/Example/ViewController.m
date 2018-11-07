//
//  ViewController.m
//  Example
//
//  Created by Olivier Poitrey on 26/09/12.
//  Copyright (c) 2012 Hackemist. All rights reserved.
//

#import "ViewController.h"
#import "SDSegmentedControl.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet SDSegmentedControl *segmentedControl;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    SDSegmentedControl *segmentedControl = SDSegmentedControl.appearance;
    segmentedControl.backgroundColor = [UIColor colorWithRed:0 green:84/255.0 blue:108/255.0 alpha:1.f];
    segmentedControl.selectedTitleFont = [UIFont systemFontOfSize:14.f weight:UIFontWeightRegular];
    segmentedControl.titleFont = [UIFont systemFontOfSize:14.f weight:UIFontWeightRegular];
    segmentedControl.arrowSize = 0;
    segmentedControl.interItemSpace = 20.f;
    segmentedControl.highlighted = NO;
    
    SDSegmentView *segmenteViewAppearance = SDSegmentView.appearance;
    [segmenteViewAppearance setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [segmenteViewAppearance setTitleColor:[UIColor colorWithRed:0 green:84/255.0 blue:108/255.0 alpha:1.f] forState:UIControlStateSelected];
    
    
    SDStainView *stainViewAppearance = SDStainView.appearance;
    stainViewAppearance.backgroundColor = [UIColor whiteColor];
    
    [self.segmentedControl insertSegmentWithTitle:@"Прогресс" atIndex:0 animated:NO];
    [self.segmentedControl insertSegmentWithTitle:@"Данные" atIndex:1 animated:NO];
}

@end
