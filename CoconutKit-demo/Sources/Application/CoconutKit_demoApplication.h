//
//  CoconutKit_demoApplication.h
//  CoconutKit-demo
//
//  Created by Samuel Défago on 2/10/11.
//  Copyright 2011 Hortis. All rights reserved.
//

@interface CoconutKit_demoApplication : NSObject <UIActionSheetDelegate> {
@private
    UINavigationController *m_navigationController;
    HLSActionSheet *m_languageActionSheet;
}

- (UIViewController *)viewController;

@end
