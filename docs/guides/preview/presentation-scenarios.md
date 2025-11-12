# Presentation Scenarios Guide

This guide documents all survey presentation scenarios supported by the Pulse Widgets Preview System.

## Overview

The preview system supports multiple ways to present surveys, each with different use cases and behaviors.

## Scenarios

### 1. Manual Button Click

**Trigger**: User clicks "Present Survey" button in the UI

**Flow**:
1. User selects survey from dropdown
2. User clicks "Present Survey" button
3. Preview app calls `presentSurvey()` with `force: true`
4. Survey is presented via bridge

**Code Example**:
```javascript
await presentSurvey(surveySelect.value, { force: true });
```

**Use Case**: Manual testing and demonstration

**Reliability**: High - explicit user action

---

### 2. Survey Select Change

**Trigger**: User changes survey selection in dropdown

**Flow**:
1. User selects different survey from dropdown
2. Change event handler triggers
3. Preview app calls `presentSurvey()` if auto-present enabled
4. Survey is presented

**Code Example**:
```javascript
surveySelect.addEventListener('change', async () => {
  await presentSurvey(surveySelect.value);
});
```

**Use Case**: Quick survey switching during testing

**Reliability**: Medium - may conflict with URL parameter scenarios

---

### 3. URL Parameter (`present`)

**Trigger**: URL contains `?present=XXXX` parameter

**Flow**:
1. Page loads with `present` parameter
2. Preview app parses parameter
3. `handlePresentParameter()` is called
4. Survey is automatically presented

**Code Example**:
```
https://preview.example.com/?present=1234
```

**Use Case**: Direct linking to specific survey, automated testing

**Reliability**: High - single presentation guaranteed

**Notes**:
- Parameter value must be exactly 4 digits
- Survey must exist in survey list
- Prevents duplicate presentations automatically

---

### 4. Behavior Triggers

**Trigger**: Simulated user behaviors (exit-intent, scroll-depth, etc.)

**Flow**:
1. Behavior is simulated (via button or auto-detection)
2. Behavior handler calls `triggerBehavior()`
3. If behavior qualifies, survey is presented
4. Presentation uses `allowDuplicate: true` to allow multiple triggers

**Code Example**:
```javascript
triggerBehavior('exit-intent', { source: 'button' });
// May trigger: presentSurvey(surveyId, { allowDuplicate: true });
```

**Use Case**: Testing behavior-based survey triggers

**Reliability**: Medium-High - intentional duplicates allowed

---

### 5. Auto-Present via Player URL

**Trigger**: Player iframe URL contains `?present=XXXX`

**Flow**:
1. Bridge loads player iframe with `present` in URL
2. Player reads `present` parameter
3. Tag script auto-presents when ready
4. Survey appears automatically

**Code Example**:
```javascript
const config = {
  account: 'PI-12345678',
  present: ['1234'] // Auto-presents survey 1234
};
bridge.load(config);
```

**Use Case**: Embedded player scenarios

**Reliability**: Medium - coordination with explicit presents needed

---

## Duplicate Prevention

All scenarios respect duplicate prevention logic:

- **Time Window**: 10 second cooldown between duplicate presentations
- **Source Priority**: Manual > URL Parameter > Behavior > Auto
- **Force Flag**: `force: true` bypasses deduplication
- **Allow Duplicate**: `allowDuplicate: true` allows duplicates

## Best Practices

1. **Use `present` parameter** for direct links and automated testing
2. **Use manual button** for interactive testing
3. **Use behavior triggers** for testing behavior-based scenarios
4. **Avoid mixing scenarios** - use one method per test session
5. **Check logs** - all presentations are logged with source information

## Troubleshooting

### Survey Not Presenting

1. Check browser console for errors
2. Verify survey ID exists in survey list
3. Check if duplicate prevention is blocking
4. Verify tag script loaded successfully
5. Check player iframe loaded correctly

### Double Presentations

1. Check if both URL parameter and manual trigger used
2. Verify duplicate prevention is working
3. Check for race conditions in async code
4. Review presentation logs for source information

### Survey Not Found

1. Verify survey ID format (4 digits)
2. Check survey exists in survey list
3. Verify survey is enabled
4. Check survey status is "Live"

## Migration from `pi_present`

The parameter name changed from `pi_present` to `present` to avoid conflicts with Pulse Insights service. Update URLs:

**Old**: `?pi_present=1234`
**New**: `?present=1234`

