const assessmentDatetimeOrder = [
    'start_time_evaluation',
    'end_time_evaluation',
    'start_time_feedback',
    'end_time_feedback'
];

function fieldInput(field) {
    return document.getElementById(field);
}

function fieldNilCheckbox(field) {
    return document.getElementById(field + '_nil');
}

function fieldIsFixed(field) {
    const checkbox = fieldNilCheckbox(field);
    const input = fieldInput(field);
    return input && (!checkbox || !checkbox.checked);
}

function syncDatetimeInput(checkbox) {
    const input = fieldInput(checkbox.dataset.datetimeField);
    if (!input) {
        return;
    }

    input.disabled = checkbox.checked;
    input.classList.toggle('collapse', checkbox.checked);
}

function previousFixedValue(index) {
    for (let i = index - 1; i >= 0; i--) {
        const field = assessmentDatetimeOrder[i];
        const input = fieldInput(field);
        if (fieldIsFixed(field) && input.value) {
            return input.value;
        }
    }
    return '';
}

function setMinimums() {
    assessmentDatetimeOrder.forEach(function(field, index) {
        const input = fieldInput(field);
        if (input) {
            input.min = previousFixedValue(index);
        }
    });
}

function pushFollowingTimes() {
    let previous = '';
    assessmentDatetimeOrder.forEach(function(field) {
        const input = fieldInput(field);
        if (!fieldIsFixed(field) || !input.value) {
            return;
        }

        if (previous && input.value < previous) {
            input.value = previous;
        }
        previous = input.value;
    });
    setMinimums();
}

function syncFeedbackStartFromEvaluationEnd() {
    const evaluationEnd = fieldInput('end_time_evaluation');
    const feedbackStart = fieldInput('start_time_feedback');
    if (!evaluationEnd || !feedbackStart || !evaluationEnd.value || !fieldIsFixed('start_time_feedback')) {
        return;
    }
    if (!feedbackStart.value || feedbackStart.value < evaluationEnd.value) {
        feedbackStart.value = evaluationEnd.value;
    }
}

function checkboxToDatetimeListener() {
    document.querySelectorAll('.checkbox_to_datetime').forEach(function(checkbox) {
        syncDatetimeInput(checkbox);

        checkbox.addEventListener('change', function() {
            syncDatetimeInput(checkbox);

            syncFeedbackStartFromEvaluationEnd();
            pushFollowingTimes();
        });
    });
}

function datetimeOrderListener() {
    assessmentDatetimeOrder.forEach(function(field) {
        const input = fieldInput(field);
        if (!input) {
            return;
        }

        input.addEventListener('change', function() {
            if (field === 'end_time_evaluation') {
                syncFeedbackStartFromEvaluationEnd();
            }
            pushFollowingTimes();
        });
    });
    setMinimums();
    syncFeedbackStartFromEvaluationEnd();
    pushFollowingTimes();
}

document.addEventListener('DOMContentLoaded', function() {
    checkboxToDatetimeListener();
    datetimeOrderListener();
});
