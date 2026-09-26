{% macro pick_label() %}
  {% if my_project.is_ci() %}
    {{ return('ci') }}
  {% else %}
    {{ return('local') }}
  {% endif %}
{% endmacro %}
