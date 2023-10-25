// Function to add the event listener
function checkbox_to_datetime_listener() {
    // Select all elements with the class "myButton"
    const checkboxs = document.querySelectorAll('.checkbox_to_datetime');

    // Add an event listener to each element
    checkboxs.forEach(function(checkbox) {
        checkbox.addEventListener('click', function() {
            input_datetime=document.getElementById(checkbox.id.replace("_nil",""))
            if (checkbox.checked) {
                input_datetime.classList.add('collapse');

            } else {
                input_datetime.classList.remove('collapse');


            }
        });
    });
}

// Add the event listener when the DOM is fully loaded
document.addEventListener('DOMContentLoaded', checkbox_to_datetime_listener);