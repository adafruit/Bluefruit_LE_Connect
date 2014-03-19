//
//  PinIOViewController.m
//  Bluefruit Connect
//
//  Created by Adafruit Industries on 2/3/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "PinIOViewController.h"
#import "NSString+hex.h"
#import "NSData+hex.h"
#import <QuartzCore/CAAnimation.h>

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
    BOOL            readReportsSent;
    uint8_t         portMasks[PORT_COUNT];   //port # as index
    double          lastTime;
}

@end


@implementation PinIOViewController


- (id)initWithDelegate:(id<PinIOViewControllerDelegate>)aDelegate{
    
    //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
    
    NSString *nibName;
    
    if (IS_IPHONE_4){
        nibName = @"PinIOViewController_iPhone";
    }
    else if (IS_IPHONE_5){
        nibName = @"PinIOViewController_iPhone568px";
    }
    else{
        nibName = @"PinIOViewController_iPad";
    }
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    
    if (self){
        self.delegate = aDelegate;
        self.title = @"Pin I/O";
        self.helpViewController.title = @"Pin I/O Help";
        readReportsSent = NO;
    }
    
    return self;
    
}


- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil{
    
    //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
    
    NSString *nibName;
    
    if (IS_IPHONE_4){
        nibName = @"PinIOViewController_iPhone";
    }
    else if (IS_IPHONE_5){
        nibName = @"PinIOViewController_iPhone568px";
    }
    else{
        nibName = @"PinIOViewController_iPad";
    }
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void)viewDidLoad{
    
    [super viewDidLoad];
    
    //initialization
    
    self.helpViewController.delegate = self.delegate;
    
    pinTableAnimating = NO;
    
    portMasks[0] = 0;
    portMasks[1] = 0;
    portMasks[2] = 0;
    
    //initialize ivars
    [self initializeCells];
    
}


- (void)viewDidAppear:(BOOL)animated{
    
    //Request pin state reporting to begin if we haven't already
    if (readReportsSent == NO){
        
        [self enableReadReports];
    }
    
}


- (void)didReceiveMemoryWarning{
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark Connection & Initialization


- (void)didConnect{
    
    //Respond to device connection
    
}


- (void)initializeCells{
    
    //Create & configure each table view cell
    
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
        //set tag to indicate digital pin number
        cell.toggleButton.tag = i;
        
        cell.modeControl = (UISegmentedControl*)[cell viewWithTag:104];
        [cell.modeControl addTarget:self action:@selector(modeControlChanged:) forControlEvents:UIControlEventValueChanged];
        //set tag to indicate digital pin number
        cell.modeControl.tag = i;
        
        cell.digitalControl = (UISegmentedControl*)[cell viewWithTag:105];
        [cell.digitalControl addTarget:self action:@selector(digitalControlChanged:) forControlEvents:UIControlEventValueChanged];
        //set tag to indicate digital pin number
        cell.digitalControl.tag = i;
        
        cell.valueSlider = (UISlider*)[cell viewWithTag:106];
        [cell.valueSlider addTarget:self action:@selector(valueControlChanged:) forControlEvents:UIControlEventValueChanged];
        //set tag to indicate digital pin number
        cell.valueSlider.tag = i;
        
        cell.delegate = self;
        
        //PWM pins
        if ((i == 3) || (i == 5) || (i == 6)) {
            cell.isPWM = YES;
        }
        
        //Digital pins
        if (i >= FIRST_DIGITAL_PIN && i <= LAST_DIGITAL_PIN) {
            //setup digital pin
            cell.digitalPin = i;
            cell.analogPin = -1;
            cell.pinLabel.text = [NSString stringWithFormat:@"Pin %d", cell.digitalPin];
            [cell setDefaultsWithMode:kPinModeInput];
        }
        
        //Analog pins
        else if (i >= FIRST_ANALOG_PIN && i <= LAST_ANALOG_PIN){
            //setup analog pin
            cell.digitalPin = i;
            cell.analogPin = i - FIRST_ANALOG_PIN;
            cell.pinLabel.text = [NSString stringWithFormat:@"Pin A%d", cell.analogPin];
            
            //starting as analog on pin 5
            if (cell.analogPin == 5) {
                [cell setDefaultsWithMode:kPinModeAnalog];
            }
            else{
                [cell setDefaultsWithMode:kPinModeInput];
            }
        }
        
        else{
            //placeholder cell
            cell.digitalPin = -1;
            cell.isAnalog = NO;
            cell.analogPin = -1;
            
        }
        
        [cells addObject:cell];
        
    }
    
}


- (void)enableReadReports{
    
    //Set all pin read reports
    for (PinCell *cell in cells) {
        if (cell.digitalPin >= 0) { //placeholder cells are -1
            
            //set read reports enabled
            [self setDigitalStateReportingforPin:cell.digitalPin enabled:YES];
            
        }
    }
    
    //set all pin modes active
    for (PinCell *cell in cells) {
        if (cell.digitalPin >= 0) { //placeholder cells are -1
            
            //set default pin mode
            [self modeControlChanged:cell.modeControl];
            
        }
    }
    
}


- (void)setDigitalStateReportingforPin:(int)digitalPin enabled:(BOOL)enabled{
    
    //Enable input/output for a digital pin
    
    //port 0: digital pins 0-7
    //port 1: digital pins 8-15
    //port 2: digital pins 16-23
    
    //find port for pin
    uint8_t port;
    uint8_t pin;
    
    //find pin for port
    if (digitalPin <= 7){       //Port 0 (aka port D)
        port = 0;
        pin = digitalPin;
    }
    
    else if (digitalPin <= 15){ //Port 1 (aka port B)
        port = 1;
        pin = digitalPin - 8;
    }
    
    else{                       //Port 2 (aka port C)
        port = 2;
        pin = digitalPin - 16;
    }
    
    uint8_t data0 = 0xd0 + port;        //start port 0 digital reporting (0xd0 + port#)
    uint8_t data1 = portMasks[port];    //retrieve saved pin mask for port;
    
    if (enabled)
        data1 |= (1<<pin);
    else
        data1 ^= (1<<pin);
    
    uint8_t bytes[2] = {data0, data1};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:2];
    
    portMasks[port] = data1;    //save new pin mask
    
    [_delegate sendData:newData];
    
}


- (void)setDigitalStateReportingforPort:(int)port enabled:(BOOL)enabled{
    
    //Enable input/output for a digital pin
    
    //Enable by port
    uint8_t data0 = 0xd0 + port;  //start port 0 digital reporting (207 + port#)
    uint8_t data1 = (uint8_t)enabled;    //Enable
    
    uint8_t bytes[2] = {data0, data1};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:2];
    
    [_delegate sendData:newData];
}


- (void)setAnalogValueReportingforAnalogPin:(int)pin enabled:(BOOL)enabled{
    
    //Enable analog read for a pin
    
    //Enable by pin
    uint8_t data0 = 0xc0 + pin;          //start analog reporting for pin (192 + pin#)
    uint8_t data1 = (uint8_t)enabled;    //Enable
    uint8_t bytes[2] = {data0, data1};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:2];
    
    [_delegate sendData:newData];
}


#pragma mark - Pin I/O Controls


- (void)digitalControlChanged:(UISegmentedControl*)sender{
    
    //Respond to user setting a digital pin high/low
    
    //Change relevant cell's value label
    PinCell *cell = [self pinCellForpin:(int)sender.tag];
    if (!cell) return;
    
    int state = (int)sender.selectedSegmentIndex;
    
    [cell setDigitalValue:(PinState)state];
    
    //Send value change to BLEBB
    [self writePinState:state forPin:cell.digitalPin];
    
}


- (void)cellButtonTapped:(UIButton*)sender{
    
    //Respond to user tapping a cell's top area to open/close cell
    
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


- (void)modeControlChanged:(UISegmentedControl*)sender{
    
    //Change relevant cell's mode
    
    PinCell *cell = [self pinCellForpin:(int)sender.tag];
    if (!cell) return;
    
    PinMode mode = [self pinModeforControl:sender];
    PinMode prevMode = cell.mode;
    [cell setMode:mode];
    
    //Write pin
    [self writePinMode:mode forPin:cell.digitalPin];
    
    //Update reporting for Analog pins
    if (cell.mode == kPinModeAnalog) {
        [self setAnalogValueReportingforAnalogPin:cell.analogPin enabled:YES];
    }
    else if (prevMode == kPinModeAnalog){
        [self setAnalogValueReportingforAnalogPin:cell.analogPin enabled:NO];
    }
    
}


- (IBAction)toggleDebugConsole:(id)sender {
    
    //For debugging in development
    
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


- (void)valueControlChanged:(UISlider*)sender{
    
    //Respond to PWM value slider changes
    
    //Limit the amount of messages we send over BLE
    double time = CACurrentMediaTime(); //Get current time
    if (time - lastTime < 0.05) {       //Bail if we're trying to send a value too soon
        return;
    }
    lastTime = time;
    
    //Find relevant cell based on slider control's tag
    PinCell *cell = [self pinCellForpin:(int)sender.tag];
    
    //Bail if we have a redundant value
    if ([cell.valueLabel.text intValue] == sender.value) {
        return;
    }
    
    //Update the cell UI for the new value
    [cell setPwmValue:sender.value];
    
    //Send the new value over BLE
    [self writePWMValue:sender.value forPin:cell.digitalPin];
    
}


#pragma mark Outgoing Data


- (void)writePinState:(PinState)newState forPin:(int)pin{
    
    //Set an output pin's state
    
    uint8_t data0 = 0;  //Status
    uint8_t data1 = 0;  //LSB of bitmask
    uint8_t data2 = 0;  //MSB of bitmask
    
    //Status byte == 144 + port#
    uint8_t port = pin / 8;
    
    data0 = 0x90 + port;
    
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
    
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:3];
    
    [_delegate sendData:newData];
    
}


- (void)writePWMValue:(uint8_t)value forPin:(uint8_t)pin{
    
    //Set an PWM output pin's value
    
    uint8_t data0 = 0;  //Status
    uint8_t data1 = 0;  //LSB of bitmask
    uint8_t data2 = 0;  //MSB of bitmask
    
    //Analog (PWM) I/O message
    data0 = 0xe0 + pin;
    data1 = value & 0x7F;   //only 7 bottom bits
    data2 = value >> 7;     //top bit in second byte
    
    uint8_t bytes[3] = {data0, data1, data2};
    
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:3];
    
    [_delegate sendData:newData];
    
}


- (void)writePinMode:(PinMode)newMode forPin:(int)pin{

    //Set a pin's mode
    
    uint8_t data0 = 0xf4;        //Status byte == 244
    uint8_t data1 = pin;        //Pin#
    uint8_t data2 = newMode;    //Mode
    
    uint8_t bytes[3] = {data0, data1, data2};
    NSData *newData = [[NSData alloc ]initWithBytes:bytes length:3];
    
    [_delegate sendData:newData];
    
}


#pragma mark Incoming Data


- (void)receiveData:(NSData*)newData{
    
    //Respond to incoming data
    
    //Debugging in dev
//    [self updateDebugConsoleWithData:newData];
    
    uint8_t data[20];
    static uint8_t buf[512];
    static int length = 0;
    int dataLength = (int)newData.length;
    
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


- (void)processInputData:(uint8_t*)data withLength:(int)length{
    
    //Parse data we received
    
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
        else if ((data[i] >= 0xe0) && (data[i] <= 0xe5)){
            
            int pin = data[i] - 0xe0 + FIRST_ANALOG_PIN;
            int val = data[i+1] + (data[i+2]<<7);
            
            if (pin <= (cells.count-1)) {
                PinCell *cell = [self pinCellForpin:pin];
                if (cell) [cell setAnalogValue:val];
            }
        }
    }
}


- (void)updateDebugConsoleWithData:(NSData*)newData{
    
    //For debugging in dev

    NSString *hexString = [newData hexRepresentationWithSpaces:YES];
    
    self.debugConsole.text = [_debugConsole.text stringByAppendingString:[NSString stringWithFormat:@"\n %@", hexString]];
    
    //scroll output to bottom
    if (_debugConsole.hidden == NO) {
        [_debugConsole scrollRangeToVisible:NSMakeRange([_debugConsole.text length], 0)];
        [_debugConsole setScrollEnabled:NO];
        [_debugConsole setScrollEnabled:YES];
    }
    
}


- (void)updateForPinStates:(int)pinStates port:(uint8_t)port{
    
    //Update pin table with new pin values received
    
    int offset = 8 * port;
    
    //Iterate through all  pins
    for (int i = 0; i <= 7; i++) {
        
        uint8_t state = pinStates;
        uint8_t mask = 1 << i;
        state = state & mask;
        state = state >> i;
        
        int cellIndex = i + offset;
        
        if (cellIndex <= (cells.count-1)) {
            
            PinCell *cell = [self pinCellForpin:cellIndex];
            if (cell && (cell.mode == kPinModeInput || cell.mode == kPinModeOutput)) {
                
                [cell setDigitalValue:state];
            }
            
        }
    }
    
    //Save reference state mask
    portMasks[port] = pinStates;
    
}


#pragma mark - Table view data source


- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView{
    
    //Always two sections - analog & digital
    
    return 2;
    
}


- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section{
    
    //return title for each section
    
    if (section == 0){
        return @"Digital";
    }
    
    else{
        return @"Analog";
    }
    
}


- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section{
    
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


- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    
    //Return appropriate cell for a row index
    
    PinCell *cell;
    
    //Set cell texts & type
    if (indexPath.section == DIGITAL_PIN_SECTION){      //Digital Pins 2-7
        int pin = (int)indexPath.row + FIRST_DIGITAL_PIN;
        cell = [self pinCellForpin:pin];
        
    }
    
    else if (indexPath.section == ANALOG_PIN_SECTION){  //Analog Pins A0-A5
        int pin = (int)indexPath.row + FIRST_ANALOG_PIN;
        cell = [self pinCellForpin:pin];
    }
    
    if (cell == nil){
        NSLog(@"-------> making a placeholder cell");
        cell = [[PinCell alloc]init];
    }
    
    return cell;
}


- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath{
    
    //Return height appropriate for cell state - open/closed
    
    CGFloat height = _pinTable.rowHeight;
    
    int cellIndex = 0;
    if (indexPath.section == DIGITAL_PIN_SECTION) {
        cellIndex = (int)indexPath.row + FIRST_DIGITAL_PIN;
    }
    else if (indexPath.section == ANALOG_PIN_SECTION){
        cellIndex = (int)indexPath.row + FIRST_ANALOG_PIN;
    }
    
    if (cellIndex >= cells.count) {return 0;}
    PinCell *cell = [self pinCellForpin:cellIndex];
    if (!cell) {return 0;}
    
    //selected
    if ([indexPath compare:openCellPath] == NSOrderedSame) {
        
        if (cell.mode == kPinModeInput || cell.mode == kPinModeAnalog) {
            height = ROW_HEIGHT_INPUT;
        }
        else height = ROW_HEIGHT_OUTPUT;
        
        cell.backgroundColor = [UIColor whiteColor];
    }
    
    //not selected
    else cell.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1.0f];
    
    return height;
}


- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section{
    
    //return height for title rows
    
    return HEADER_HEIGHT;
    
}


- (PinCell*)pinCellForpin:(int)pin{
    
    //Retrieve appropriate cell for a pin number
    
    if (pin >= cells.count) {return nil;}
    
    PinCell *matchingCell;
    
    for (PinCell *cell in cells) {
        if (cell.digitalPin == pin) {
            matchingCell = cell;
            break;
        }
    }
    
    return matchingCell;
    
}


#pragma mark Helper methods


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
    
    //Animate row height changes for user selection
    
    [_pinTable beginUpdates];
    [_pinTable endUpdates];
}


- (void)scrollToIndexPath:(NSIndexPath*)indexPath{
    
    //Scroll to a particular row on the table
    
    [_pinTable scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
    
}


- (void)cellModeUpdated:(id)sender{
    
    //Respond to mode change for a cell
    
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
