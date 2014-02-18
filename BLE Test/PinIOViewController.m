//
//  PinIOViewController.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/3/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "PinIOViewController.h"
#import "NSString+hex.h"
#import "NSData+hex.h"

#define SECTION_COUNT 2
#define HEADER_HEIGHT 40.0f
#define ROW_HEIGHT_INPUT 110.0f
#define ROW_HEIGHT_OUTPUT 150.0f
#define MAX_CELL_COUNT 20
#define DIGITAL_PIN_SECTION 0
#define ANALOG_PIN_SECTION 1
#define FIRST_DIGITAL_PIN 3
#define LAST_DIGITAL_PIN 8
#define FIRST_ANALOG_PIN 14
#define LAST_ANALOG_PIN 19
#define PORT_COUNT 3


@interface PinIOViewController (){
    
    NSIndexPath     *openCellPath;
    NSMutableArray  *cells;
    CGRect          tableVisibleBounds;
    CGRect          tableOffScreenBounds;
    BOOL            pinTableAnimating;
    uint8_t         portMasks[PORT_COUNT];   //port # as index
    
}

@end


@implementation PinIOViewController


- (id)initWithDelegate:(id<PinIOViewControllerDelegate>)aDelegate{
    
    NSString *nibName = IS_IPAD ? @"PinIOViewController_iPad" : @"PinIOViewController_iPhone";
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    
    if (self){
        self.delegate = aDelegate;
        self.title = @"Pin I/O";
        self.helpViewController.title = @"Pin I/O Help";
    }
    
    return self;
    
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    
    NSString *nibName = IS_IPAD ? @"PinIOViewController_iPad" : @"PinIOViewController_iPhone";
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void)viewDidLoad{
    
//    NSLog(@"Pin I/O Controller - View Did Load");
    
    [super viewDidLoad];
    
    self.helpViewController.delegate = self.delegate;
    
    pinTableAnimating = NO;
    
    portMasks[0] = 0;
    portMasks[1] = 0;
    portMasks[2] = 0;
    
    //initialize ivars
    [self initializeCells];
    
    //Set initial mode states
//    [self writeInitialModeStates];
    
}


- (void)viewDidAppear:(BOOL)animated{
    
    //set all pin modes active
    for (PinCell *cell in cells) {
        [self modeControlChanged:cell.modeControl];
    }
    
    [self enableRead];
}


- (void)didReceiveMemoryWarning{
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark Connection & Initialization


- (void)didConnect{
    
//    NSLog(@"Pin I/O Controller - Did Connect");
    
    //Respond to connection to BLE UART
    
    //Set all available pins as Input
//    for (int i = 2; i <= 19; i++) {
//        //Skip reserved pins
//        if ((i > LAST_DIGITAL_PIN) && (i < FIRST_ANALOG_PIN)) continue;
//        //Write mode and set initial state
//        [self writePinMode:kPinModeInput forPin:i];
//        [(PinCell*)[cells objectAtIndex:i] setMode:kPinModeInput];
//    }
    
    
    //Enable analog reads
//    for (int i = 0; i<=5; i++) {
//        [self setAnalogValueReportingforAnalogPin:i enabled:YES];
//    }
    
    //Write last two pins LOW   -   hack for prev version?
//    [self writePinState:kPinStateLow forPin:14];
//    [self writePinState:kPinStateLow forPin:15];
    
}


- (void)initializeCells{
    
    cells = [[NSMutableArray alloc]initWithCapacity:MAX_CELL_COUNT];
    
    for (int i = 0; i<MAX_CELL_COUNT; i++) {
        
        PinCell *cell = [NSKeyedUnarchiver unarchiveObjectWithData:
                         [NSKeyedArchiver archivedDataWithRootObject:_digitalPinCell]];
        
        //Assign properties via tags
        cell.pinLabel = (UILabel*)[cell viewWithTag:100];
        cell.modeLabel = (UILabel*)[cell viewWithTag:101];
        cell.valueLabel = (UILabel*)[cell viewWithTag:102];
        
        cell.toggleButton = (UIButton*)[cell viewWithTag:103];
        [cell.toggleButton addTarget:self action:@selector(cellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        cell.modeControl = (UISegmentedControl*)[cell viewWithTag:104];
        [cell.modeControl addTarget:self action:@selector(modeControlChanged:) forControlEvents:UIControlEventValueChanged];
        
        cell.digitalControl = (UISegmentedControl*)[cell viewWithTag:105];
        [cell.digitalControl addTarget:self action:@selector(digitalControlChanged:) forControlEvents:UIControlEventValueChanged];
        
        cell.valueSlider = (UISlider*)[cell viewWithTag:106];
        [cell.valueSlider addTarget:self action:@selector(valueControlChanged:) forControlEvents:UIControlEventValueChanged];
        
        cell.delegate = self;
        
        [cell setDefaultsWithMode:kPinModeInput];
        
        [cells addObject:cell];
    }
    
}


//- (void)writeInitialModeStates{
//    
//    //Debug
////    NSLog(@"cells count == %d", cells.count);
//    
//    //write starting modes as Input
//    for (PinCell *cell in cells) {
//        
//        NSLog(@"cell label == %@", cell.pinLabel.text);
//        
//        [cell.modeControl setSelectedSegmentIndex:kPinModeInput];
//        [cell setMode:kPinModeInput];
//        [self modeControlChanged:cell.modeControl];
//    }
//    
//}


- (void)enableRead{
    
    //Enable monitoring of pin values / input
    
    [self setDigitalStateReportingforPort:0 enabled:YES];
    [self setDigitalStateReportingforPort:1 enabled:YES];
    [self setDigitalStateReportingforPort:2 enabled:YES];
    
    //Enable analog reads
    for (int i = 0; i<=5; i++) {
        [self setAnalogValueReportingforAnalogPin:i enabled:YES];
    }
    
}


- (void)setDigitalStateReportingforPort:(int)port enabled:(BOOL)enabled{
    
    //Enable input/output for a digital pin
    
    //Enable Port
//    uint8_t data0 = 208 + port;  //start port 0 digital reporting (207 + port#)
    
    uint8_t data0 = 0xD0 + port;  //start port 0 digital reporting (207 + port#)
    uint8_t data1 = (uint8_t)enabled;    //Enable
    uint8_t bytes[2] = {data0, data1};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:2];
    
    [_delegate sendData:newData];
}


- (void)setAnalogValueReportingforAnalogPin:(int)pin enabled:(BOOL)enabled{
    
    //Enable analog read for a pin
    
    //Enable Port
    uint8_t data0 = 0xC0 + pin;  //start analog reporting for pin (192 + pin#)
    uint8_t data1 = (uint8_t)enabled;    //Enable
    uint8_t bytes[2] = {data0, data1};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:2];
    
    [_delegate sendData:newData];
}


#pragma mark - Pin I/O Controls


- (void)digitalControlChanged:(UISegmentedControl*)sender{
    
    //Respond to user setting a digital pin high/low
    
    //Change relevant cell's value label
    PinCell *cell = [self pinCellForSubview:sender];
    
    int state = sender.selectedSegmentIndex;
    
    [cell setWrittenValue:(PinState)state];
    
    //Send value change to BLEBB
    [self writePinState:(PinState)state forPin:cell.digitalPin];
    
    
    //PWM & Servo
    //    else{
    //        UISlider * slider = (UISlider*)sender;
    //        cell.valueLabel.text = [NSString stringWithFormat:@"%d", (int)roundf(slider.value)];
    //
    //        //Send value change to BLEBB
    //        NSLog(@"IMPLEMENT PWM/SERVO CONTROL");
    //    }
    
}


- (void)cellButtonTapped:(UIButton*)sender{
    
    //Respond to user tapping a cell
    
    //find relevant indexPath
    NSIndexPath *indexPath = [self indexPathForSubview:sender];
    
    //if same button is tapped as previous, close the cell
    if ([indexPath compare:openCellPath] == NSOrderedSame) {
        openCellPath = nil;
    }
    else {
        openCellPath = indexPath;
    }
    
    [self updateTable];
    
    //if opening, scroll table until cell is visble
    if (indexPath != nil) {
        [self performSelector:@selector(scrollToIndexPath:)
                   withObject:indexPath
                   afterDelay:0.25f];
    }
    
}


- (void)modeControlChanged:(id)sender{
    
    //Change relevant cell's mode
    
    PinCell *cell = [self pinCellForSubview:sender];
    PinMode mode = [self pinModeforControl:(UISegmentedControl*)sender];
    [cell setMode:mode];
    
    //Write pin
    [self writePinMode:mode forPin:cell.digitalPin];
}


- (IBAction)toggleDebugConsole:(id)sender {
    
    _debugConsole.hidden = !_debugConsole.hidden;
    
}


- (PinMode)pinModeforControl:(UISegmentedControl*)control{
    
    //Convert segmented control selection to pin state
    
    NSString *modeString = [control titleForSegmentAtIndex:control.selectedSegmentIndex];
    
    PinMode mode = kPinModeUnknown;
    
    if ([modeString compare:@"Input"] == NSOrderedSame) {
        mode = kPinModeInput;
    }
    else if ([modeString compare:@"Output"] == NSOrderedSame) {
        mode = kPinModeOutput;
    }
    else if ([modeString compare:@"Analog"] == NSOrderedSame) {
        mode = kPinModeAnalog;
    }
    else if ([modeString compare:@"PWM"] == NSOrderedSame) {
        mode = kPinModePWM;
    }
    else if ([modeString compare:@"Servo"] == NSOrderedSame) {
        mode = kPinModeServo;
    }
    
    return mode;
}


- (void)valueControlChanged:(id)sender{
    
    //respond to PWM & Servo control here
    
}


#pragma mark Outgoing Data


- (void)writePinState:(PinState)newState forPin:(int)pin{
    
    //Set an output pin's state
    
    uint8_t data0 = 0;  //Status
    uint8_t data1 = 0;  //LSB of bitmask
    uint8_t data2 = 0;  //MSB of bitmask
    
    //Status byte == 144 + port#
    uint8_t port = pin / 8;
    
    data0 = 144 + port;
    
    //Data1 == pin0State + 2*pin1State + 4*pin2State + 8*pin3State + 16*pin4State + 32*pin5State
    uint8_t pinIndex = pin - (port*8);
    uint8_t newMask = newState * powf(2, pinIndex);
    
    if (port == 0) {
        
        portMasks[port] &= ~(1 << pinIndex); //prep the saved mask by zeroing this pin's corresponding bit
        
        newMask |= portMasks[port]; //merge with saved port state
        portMasks[port] = newMask;
        data1 = newMask<<1; data1 >>= 1;  //remove MSB
        data2 = newMask >> 7; //use data1's MSB as data2's LSB
    }
    
    else {
        portMasks[port] &= ~(1 << pinIndex); //prep the saved mask by zeroing this pin's corresponding bit
        newMask |= portMasks[port]; //merge with saved port state
        portMasks[port] = newMask;
        data1 = newMask;
        data2 = 0;
        //Hack for firmata pin15 reporting bug?
        if (port == 1) {
            data2 = newMask>>7;
            data1 &= ~(1<<7);
        }
    }
    
    uint8_t bytes[3] = {data0, data1, data2};
    
    //debugging …
//    NSLog(@"Writing pin%d on port%d - used pinIndex%d", pin, port, pinIndex);
//    NSLog(@"WRITING PIN STATE DATA: %d, %@, %@", data0, [self binaryStringForInt:data1], [blebbManager binaryStringForInt:data2]);
    
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:3];
    
    [_delegate sendData:newData];
    
}


- (void)writePinMode:(PinMode)newMode forPin:(int)pin{

    //Set a pin's mode
    
    //debugging …
//    NSLog(@"----> Setting pin %d to mode %d", pin, newMode);
    
    uint8_t data0 = 0xF4;        //Status byte == 244
    uint8_t data1 = pin;        //Pin#
    uint8_t data2 = newMode;    //Mode
    
    //debugging …
//    NSLog(@"WRITING PIN MODE DATA: %d  %d  %d", data0, data1, data2);
    
    uint8_t bytes[3] = {data0, data1, data2};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:3];
    
    [_delegate sendData:newData];
    
}


#pragma mark Incoming Data


- (void)receiveData:(NSData *)newData{
    
    //respond to incoming data
    
    [self updateDebugConsoleWithData:newData];
    
    uint8_t data[20];
    static uint8_t buf[512];
    static int length = 0;
    int dataLength = newData.length;
    
    [newData getBytes:&data length:dataLength];
    
    if (dataLength < 20){
        
        memcpy(&buf[length], data, dataLength);
        length += dataLength;
        
        [self processInputData:buf withLength:length];
        length = 0;
    }
    
    else if (dataLength == 20){
        
        memcpy(&buf[length], data, 20);
        length += dataLength;
        
        if (length >= 64){
            
            [self processInputData:buf withLength:length];
            length = 0;
        }
    }
    
}


- (void)processInputData:(uint8_t *)data withLength:(int)length{
    
    //each message is 3 bytes long
    for (int i = 0; i < length; i+=3){
        
        //Digital Reporting (per port)
        //Port 0
        if (data[i] == 0x90) {
            uint8_t pinStates = data[i+1];
            pinStates |= data[i+2] << 7;    //use LSB of third byte for pin7
            [self updateForPinStates:pinStates port:0];
            return;
        }
        
        //Port 1
        else if (data[i] == 0x91){
            uint8_t pinStates = data[i+1];
            pinStates |= (data[i+2] << 7);  //pins 14 & 15
            [self updateForPinStates:pinStates port:1];
            return;
        }
        
        //Port 2
        else if (data[i] == 0x92) {
            uint8_t pinStates = data[i+1];
            [self updateForPinStates:pinStates port:2];
            return;
        }
        
        //Analog Reporting (per pin)
        if (data[i] >= 224 && data[i] <= 243){
            
            int pin = data[i] - 224 + FIRST_ANALOG_PIN;
            int val = data[i+1] + (data[i+2]<<7);
            
            if (pin <= (cells.count-1)) {
                [[cells objectAtIndex:pin]setReceivedValue:val];
            }
        }
    }
}


- (void)updateDebugConsoleWithData:(NSData*)newData{
    
    //for debugging …
//    NSString *string = [NSString stringWithUTF8String:[newData bytes]];
//    NSString *hexString = [NSString stringToHexSpaceSeparated:string];

    NSString *hexString = [newData hexRepresentationWithSpaces:YES];
    
    self.debugConsole.text = [_debugConsole.text stringByAppendingString:[NSString stringWithFormat:@"\n %@", hexString]];
    
    //scroll output to bottom
    [_debugConsole scrollRangeToVisible:NSMakeRange([_debugConsole.text length], 0)];
    [_debugConsole setScrollEnabled:NO];
    [_debugConsole setScrollEnabled:YES];
    
}


- (void)updateForPinStates:(int)pinStates port:(uint8_t)port{
    
    //update table with new pin values
    
    int offset = 8 * port;
    
    //Iterate through all  pins
    for (int i = 0; i <= 7; i++) {
        
        uint8_t state = pinStates;
        uint8_t mask = 1 << i;
        state = state & mask;
        state = state >> i;
        
        int cellIndex = i + offset;
        
        if (cellIndex <= (cells.count-1)) {
            [[cells objectAtIndex:cellIndex]setReceivedValue:state];
            
        }
    }
    
    //Save reference state mask
    portMasks[port] = pinStates;
    
}


#pragma mark - Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    
    //there are two sections - analog & digital
    
    return 2;
    
}


- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    
    //return title for each section
    
    if (section == 0)
        return @"Digital";
    
    else return @"Analog";
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    //return the number of rows in a particular section
    
    int count = 0;
    
    if (section == DIGITAL_PIN_SECTION) {
        count = LAST_DIGITAL_PIN - FIRST_DIGITAL_PIN + 1;
    }
    else if (section == ANALOG_PIN_SECTION){
        count = LAST_ANALOG_PIN - FIRST_ANALOG_PIN + 1;
    }
    
    return count;
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    //return cell for a particular row index
    
    PinCell *cell;
    
    //Set cell texts & type
    if (indexPath.section == DIGITAL_PIN_SECTION){    //Digital Pins 2-7
        int pin = indexPath.row + FIRST_DIGITAL_PIN;
        cell = [cells objectAtIndex:pin];
        cell.digitalPin = pin;
        cell.analogPin = -1;
        cell.pinLabel.text = [NSString stringWithFormat:@"Pin %d", cell.digitalPin];
    }
    
    else {                                            //Analog Pins A0-A5
        int pin = indexPath.row + FIRST_ANALOG_PIN;
        cell = [cells objectAtIndex:pin];
        cell.digitalPin = pin;
        cell.analogPin = indexPath.row;
        cell.pinLabel.text = [NSString stringWithFormat:@"Pin A%d", cell.analogPin];
    }
    
    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    //return height appropriate for cell state - selected or unselected
    
    CGFloat height = _pinTable.rowHeight;
    
    int cellIndex = 0;
    if (indexPath.section == DIGITAL_PIN_SECTION) {
        cellIndex = indexPath.row + FIRST_DIGITAL_PIN;
    }
    else if (indexPath.section == ANALOG_PIN_SECTION){
        cellIndex = indexPath.row + FIRST_ANALOG_PIN;
    }
    
    PinCell *cell = (PinCell*)[cells objectAtIndex:(cellIndex)];
    
    if ([indexPath compare:openCellPath] == NSOrderedSame) {
        
        if (cell.mode == kPinModeInput || cell.mode == kPinModeAnalog) {
            height = ROW_HEIGHT_INPUT;
        }
        else height = ROW_HEIGHT_OUTPUT;
        
        cell.backgroundColor = [UIColor whiteColor];
    }
    
    //non-selected
    else cell.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
    
    return height;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    
    //return height for title rows
    
    return HEADER_HEIGHT;
    
}


#pragma mark Helper methods


- (PinCell*)pinCellForSubview:(UIView*)theView{
    
    //Find the cell which contains theView
    
    NSIndexPath *indexPath = [self indexPathForSubview:theView];
    
    return (PinCell*)[_pinTable cellForRowAtIndexPath:indexPath];
}


- (NSIndexPath*)indexPathForSubview:(UIView*)theView{
    
    //Find the indexpath for the cell which contains theView
    
    NSIndexPath *indexPath = nil;
    int counter = 0;  int limit = 20;
    
    while (indexPath == nil) {
        if (counter > limit) break;
        if ([theView.superview isKindOfClass:[UITableViewCell class]] == YES) {
            UITableViewCell *theCell = (UITableViewCell*)theView.superview;
            indexPath = [_pinTable indexPathForCell:theCell];
        }
        else {
            theView = theView.superview;
        }
        counter++;
    }
    
    return indexPath;
}


- (void)updateTable{
    
    //animate row height changes for user selection
    
    [_pinTable beginUpdates];
    [_pinTable endUpdates];
}


- (void)scrollToIndexPath:(NSIndexPath*)indexPath{
    
    //scroll to a particular row on the table
    
    [_pinTable scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
    
}


- (void)cellModeUpdated:(id)sender{
    
    //respond to mode change for a cell
    
    [self updateTable];
    
}


#pragma mark Data Conversion


- (NSString*)binaryStringForInt:(int)value{
    
    NSString *bits = @"";
    
    for(int i = 0; i < 8; i ++) {
        bits = [NSString stringWithFormat:@"%i%@", value & (1 << i) ? 1 : 0, bits];
    }
    
    return bits;
}


- (NSString*)stringForPinMode:(PinMode)mode{
    
    NSString *modeString;
    switch (mode) {
        case kPinModeInput:
            modeString = @"Input";
            break;
        case kPinModeOutput:
            modeString = @"Output";
            break;
        case kPinModeAnalog:
            modeString = @"Analog";
            break;
        case kPinModePWM:
            modeString = @"PWM";
            break;
        case kPinModeServo:
            modeString = @"Servo";
            break;
        default:
            modeString = @"NOT FOUND";
            break;
    }
    
    return modeString;
}


@end
