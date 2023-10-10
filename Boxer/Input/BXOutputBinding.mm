/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXOutputBinding.h"

#pragma mark - Private constants


//The fraction below which two input values will be considered equal.
#define BXOutputBindingEpsilon 0.0001

//The period at which BXPeriodicOutputBinding fires signals.
#define kBXPeriodicOutputBindingPeriod 1 / 30.0


#pragma mark - Base class implementations

@interface BXBaseOutputBinding ()

@property (assign, nonatomic) float latestValue;
@property (assign, nonatomic) float latestNormalizedValue;

@end

@implementation BXBaseOutputBinding

+ (id) binding
{
    return [[self alloc] init];
}

- (void) applyInputValue: (float)value
{
    float normalizedValue = [self normalizedValue: value];
    
    if (ABS(normalizedValue - self.latestNormalizedValue) > BXOutputBindingEpsilon)
    {
        [self applyNormalizedInputValue: normalizedValue];
        self.latestNormalizedValue = normalizedValue;
    }
    self.latestValue = value;
}

- (void) applyNormalizedInputValue: (float)value
{
	//Unimplemented at this level, must be overridden in subclasses
	[self doesNotRecognizeSelector: _cmd];
}

- (float) normalizedValue: (float)value
{
    value = MIN(value, kBXOutputBindingMax);
    value = MAX(value, kBXOutputBindingMin);
    
    if (value <= self.threshold)
        value = kBXOutputBindingMin;
    
    if (self.inverted)
        value = kBXOutputBindingMax - value;
    
    return value;
}

- (float) effectiveValue
{
    return kBXOutputBindingMin;
}

@end


#pragma mark - Joystick bindings

@implementation BXBaseEmulatedJoystickBinding
@end

@implementation BXEmulatedJoystickButtonBinding

#pragma mark - Binding behaviour

- (float) effectiveValue
{
    return [self.joystick buttonIsDown: self.button] ? kBXOutputBindingMax : kBXOutputBindingMin;
}

- (void) applyNormalizedInputValue: (float)value
{
    if (value > 0)
        [self.joystick buttonDown: self.button];
    else
        [self.joystick buttonUp: self.button];
}

#pragma mark - Initialization and deallocation

+ (id) bindingWithJoystick: (id<BXEmulatedJoystick>)joystick button: (BXEmulatedJoystickButton)button
{
    BXEmulatedJoystickButtonBinding *binding = [self binding];
    binding.joystick = joystick;
    binding.button = button;
    return binding;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"%@ binding to joystick %@ button %lu", self.class, self.joystick.class, (unsigned long)self.button];
}

@end


@implementation BXEmulatedJoystickAxisBinding

#pragma mark - Binding behaviour

- (float) effectiveValue
{
    return [self.joystick positionForAxis: self.axisName];
}

- (float) normalizedValue: (float)value
{
    return [super normalizedValue: value] * self.polarity;
}

- (void) applyNormalizedInputValue: (float)value
{
    [self.joystick setPosition: value forAxis: self.axisName];
}

#pragma mark - Initialization and deallocation

+ (id) bindingWithJoystick: (id<BXEmulatedJoystick>)joystick axis: (NSString *)axisName polarity: (BXAxisPolarity)polarity
{
    BXEmulatedJoystickAxisBinding *binding = [self binding];
    binding.joystick = joystick;
    binding.axisName = axisName;
    binding.polarity = polarity;
    return binding;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.polarity = kBXAxisPositive;
    }
    return self;
}

- (NSString *)description
{
    NSString *polarityDesc = (self.polarity == kBXAxisPositive) ? @"+" : @"-";
    return [NSString stringWithFormat: @"%@ binding to joystick %@ %@ %@", self.class, self.joystick.class, self.axisName, polarityDesc];
}
@end


@implementation BXEmulatedJoystickPOVDirectionBinding

#pragma mark - Binding behaviour

- (float) effectiveValue
{
    return [(id <BXEmulatedFlightstick>)self.joystick POV: self.POVNumber directionIsDown: self.POVDirection] ? kBXOutputBindingMax : kBXOutputBindingMin;
}

- (void) applyNormalizedInputValue: (float)value
{
    if (value > 0)
    {
        [(id <BXEmulatedFlightstick>)self.joystick POV: self.POVNumber directionDown: self.POVDirection];
    }
    else
    {
        [(id <BXEmulatedFlightstick>)self.joystick POV: self.POVNumber directionUp: self.POVDirection];
    }
}

#pragma mark - Initialization and deallocation

+ (id) bindingWithJoystick: (id<BXEmulatedJoystick>)joystick
                       POV: (NSUInteger)POVNumber
                 direction: (BXEmulatedPOVDirection)direction
{
    BXEmulatedJoystickPOVDirectionBinding *binding = [self binding];
    binding.joystick = joystick;
    binding.POVNumber = POVNumber;
    binding.POVDirection = direction;
    return binding;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"%@ binding to joystick %@ POV %lu direction %lu", self.class, self.joystick.class, (unsigned long)self.POVNumber, (unsigned long)self.POVDirection];
}
@end


#pragma mark - Keyboard bindings

@implementation BXEmulatedKeyboardKeyBinding

#pragma mark - Binding behaviour

- (float) effectiveValue
{
    return [self.keyboard keyIsDown: self.keyCode] ? kBXOutputBindingMax : kBXOutputBindingMin;
}

- (void) applyNormalizedInputValue: (float)value
{
    if (value > 0)
        [self.keyboard keyDown: self.keyCode];
    else
        [self.keyboard keyUp: self.keyCode];
}

#pragma mark - Initialization and deallocation

+ (id) bindingWithKeyboard: (BXEmulatedKeyboard *)keyboard keyCode: (BXDOSKeyCode)keyCode
{
    BXEmulatedKeyboardKeyBinding *binding = [self binding];
    binding.keyboard = keyboard;
    binding.keyCode = keyCode;
    return binding;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"%@ binding to key code %lu", self.class, (unsigned long)self.keyCode];
}
@end



#pragma mark Meta-bindings

@interface BXPeriodicOutputBinding ()

//NOTE: timers retain their targets, so we keep a weak reference to the timer to avoid a circular retain.
@property (weak, nonatomic) NSTimer *timer;
@property (nonatomic) NSTimeInterval lastUpdated;

//Called by the timer. Calculates the elapsed time, calls applyPeriodicUpdateForTimeStep:, and notifies the delegate.
- (void) _applyPeriodicUpdate;

- (void) _startUpdating;
- (void) _stopUpdating;

@end

@implementation BXPeriodicOutputBinding

#pragma mark - Binding behaviour

- (void) applyNormalizedInputValue: (float)value
{
    if (value > 0)
        [self _startUpdating];
    else
        [self _stopUpdating];
}

- (void) _applyPeriodicUpdate
{
    if (self.latestNormalizedValue > 0)
    {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval elapsedTime = now - self.lastUpdated;
        [self applyPeriodicUpdateForTimeStep: elapsedTime];
        self.lastUpdated = now;
        
        [self.delegate outputBindingDidUpdate: self];
    }
}

- (void) applyPeriodicUpdateForTimeStep: (NSTimeInterval)timeStep
{
    //Must be implemented by subclasses
    [self doesNotRecognizeSelector: _cmd];
}

- (void) _startUpdating
{
    if (!self.timer)
    {
        self.lastUpdated = [NSDate timeIntervalSinceReferenceDate];
        self.timer = [NSTimer scheduledTimerWithTimeInterval: self.period
                                                      target: self
                                                    selector: @selector(_applyPeriodicUpdate)
                                                    userInfo: nil
                                                     repeats: YES];
    }
}

- (void) _stopUpdating
{
    [self.timer invalidate];
    self.timer = nil;
}

#pragma mark - Initialization and deallocation

- (id) init
{
    self = [super init];
    if (self)
    {
        self.period = kBXPeriodicOutputBindingPeriod;
    }
    return self;
}

- (void) dealloc
{
    [self _stopUpdating];
}

@end


@implementation BXEmulatedJoystickAxisAdditiveBinding

#pragma mark - Binding behaviour

- (void) applyPeriodicUpdateForTimeStep: (NSTimeInterval)timeStep
{
    //Work out how much to increment the axis by for the current timestep.
    float increment = (self.ratePerSecond * self.latestNormalizedValue) * timeStep;
    
    float currentValue = [self.joystick positionForAxis: self.axisName];
    float newValue = currentValue + increment;
    
    //Snap the value if it's close to zero.
    if (ABS(newValue) < self.outputThreshold)
        newValue = 0;
    
    [self.joystick setPosition: newValue forAxis: self.axisName];
}


#pragma mark - Initialization and deallocation

+ (id) bindingWithJoystick: (id<BXEmulatedJoystick>)joystick axis: (NSString *)axisName rate: (float)ratePerSecond
{
    BXEmulatedJoystickAxisAdditiveBinding *binding = [self binding];
    binding.joystick = joystick;
    binding.axisName = axisName;
    binding.ratePerSecond = ratePerSecond;
    return binding;
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"%@ binding to joystick %@ %@ rate %0.2f", self.class, self.joystick.class, self.axisName, self.ratePerSecond];
}
@end



@implementation BXTargetActionBinding

+ (id) bindingWithTarget: (id)target pressedAction: (SEL)pressedAction releasedAction: (SEL)releasedAction
{
    BXTargetActionBinding *binding = [self binding];
    binding.target = target;
    binding.pressedAction = pressedAction;
    binding.releasedAction = releasedAction;
    return binding;
}

- (void) applyNormalizedInputValue: (float)value
{
    if (value > 0)
    {
        if (self.pressedAction)
            [NSApp sendAction: self.pressedAction to: self.target from: self];
    }
    else
    {
        if (self.releasedAction)
            [NSApp sendAction: self.releasedAction to: self.target from: self];
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat: @"%@ binding to target %@ pressed action %@ released action %@", self.class, self.target, NSStringFromSelector(self.pressedAction), NSStringFromSelector(self.releasedAction)];
}

@end
