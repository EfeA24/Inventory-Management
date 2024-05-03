REPORT ZINVENTORY_MANAGEMENT.

* Data Elements
DATA: BEGIN OF wa_material,
        material_id TYPE MATERIALS-MATNR,
        material_name TYPE MATERIALS-MAKTX,
        quantity TYPE i,
        price TYPE p DECIMALS 2,
      END OF wa_material.

TYPES: BEGIN OF ty_transaction,
         material_id TYPE MATERIALS-MATNR,
         material_name TYPE MATERIALS-MAKTX,
         transaction_type TYPE CHAR1,
         quantity TYPE i,
         price TYPE p DECIMALS 2,
       END OF ty_transaction.

TYPES: BEGIN OF ty_report_data,
         material_id TYPE MATERIALS-MATNR,
         material_name TYPE MATERIALS-MAKTX,
         quantity TYPE i,
         price TYPE p DECIMALS 2,
       END OF ty_report_data.

* Domains
DOMAIN material_id_domain TYPE MATERIALS-MATNR.
DOMAIN material_name_domain TYPE MATERIALS-MAKTX.
DOMAIN quantity_domain TYPE i.
DOMAIN price_domain TYPE p DECIMALS 2.

* Data Elements
DATA: material_id TYPE material_id_domain,
      material_name TYPE material_name_domain,
      quantity TYPE quantity_domain,
      price TYPE price_domain.

PARAMETERS: p_material TYPE MATERIALS-MATNR OBLIGATORY,
            p_quantity TYPE i OBLIGATORY,
            p_price TYPE p DECIMALS 2 OBLIGATORY,
            p_transaction_type TYPE CHAR1 AS CHECKBOX DEFAULT 'X'.

START-OF-SELECTION.
  PERFORM check_authorization.
  PERFORM validate_input_data.
  PERFORM process_transaction.
  PERFORM display_inventory_report.

* Subroutine to validate input data
FORM validate_input_data.
  DATA: lv_error_message TYPE string.

  IF p_quantity <= 0.
    lv_error_message = 'Quantity must be greater than 0.'.
    MESSAGE e002(zz) WITH lv_error_message.
    EXIT.
  ENDIF.

  IF p_price <= 0.
    lv_error_message = 'Price must be greater than 0.'.
    MESSAGE e002(zz) WITH lv_error_message.
    EXIT.
  ENDIF.
ENDFORM.

* Subroutine to perform authorization checks
FORM check_authorization.
  IF sy-uname NE 'ADMIN'.
    AUTHORITY-CHECK OBJECT 'ZINVENTORY' 
      ID 'ACTVT' FIELD '03'.
    IF sy-subrc NE 0.
      MESSAGE e003(zz) WITH 'You are not authorized to perform this action.'.
      EXIT.
    ENDIF.
  ENDIF.
ENDFORM.

* Subroutine to process transaction
FORM process_transaction.
  CLEAR wa_material.

  wa_material-material_id = p_material.

  IF p_transaction_type EQ 'X'.
    wa_material-transaction_type = '+'.
  ELSE.
    wa_material-transaction_type = '-'.
  ENDIF.

  wa_material-quantity = p_quantity.
  wa_material-price = p_price.

  APPEND wa_material TO it_transactions.

  SELECT SINGLE * FROM MATERIALS INTO wa_material
    WHERE MATNR = p_material.

  IF sy-subrc EQ 0.
    IF p_transaction_type EQ 'X'.
      wa_material-quantity = wa_material-quantity + p_quantity.
    ELSE.
      IF wa_material-quantity >= p_quantity.
        wa_material-quantity = wa_material-quantity - p_quantity.
      ELSE.
        MESSAGE e001(zz) WITH 'Insufficient stock.'.
        EXIT.
      ENDIF.
    ENDIF.
    MODIFY MATERIALS FROM wa_material.
  ELSE.
    IF p_transaction_type EQ 'X'.
      wa_material-material_id = p_material.
      wa_material-quantity = p_quantity.
      wa_material-price = p_price.
      INSERT INTO MATERIALS VALUES wa_material.
    ELSE.
      MESSAGE e001(zz) WITH 'Material not found.'.
      EXIT.
    ENDIF.
  ENDIF.
ENDFORM.

* Subroutine to display inventory report using ALV
FORM display_inventory_report.
  CLEAR: wa_material, it_materials[].

  SELECT * FROM MATERIALS INTO TABLE it_materials.

  IF NOT it_materials[] IS INITIAL.
    PERFORM build_alv_field_catalog.

    CREATE OBJECT gr_alv
      EXPORTING
        i_parent = cl_gui_container=>screen0.

    CALL METHOD gr_alv->set_table_for_first_display
      EXPORTING
        is_layout  = gs_alv
      CHANGING
        it_outtab  = it_materials[].

  ELSE.
    WRITE: / 'No inventory data found.'.
  ENDIF.
ENDFORM.

* Subroutine to build ALV field catalog
FORM build_alv_field_catalog.
  CLEAR gt_alv.
  CLEAR gs_alv.

  gs_alv-fieldname = 'MATERIAL_ID'.
  gs_alv-inttype = 'C'.
  gs_alv-outputlen = 15.
  gs_alv-seltext_l = 'Material ID'.
  APPEND gs_alv TO gt_alv.

  gs_alv-fieldname = 'MATERIAL_NAME'.
  gs_alv-inttype = 'C'.
  gs_alv-outputlen = 30.
  gs_alv-seltext_l = 'Material Name'.
  APPEND gs_alv TO gt_alv.

  gs_alv-fieldname = 'QUANTITY'.
  gs_alv-inttype = 'N'.
  gs_alv-outputlen = 10.
  gs_alv-seltext_l = 'Quantity'.
  APPEND gs_alv TO gt_alv.

  gs_alv-fieldname = 'PRICE'.
  gs_alv-inttype = 'P'.
  gs_alv-decimals = 2.
  gs_alv-outputlen = 15.
  gs_alv-seltext_l = 'Price'.
  APPEND gs_alv TO gt_alv.

  CLEAR gs_alv.
  gs_alv-zebra = 'X'.
  APPEND gs_alv TO gt_alv.

  CLEAR gs_alv.
  gs_alv-box_fieldname = 'MATERIAL_ID'.
  APPEND gs_alv TO gt_alv.

  CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
    EXPORTING
      i_structure_name = 'WA_MATERIAL'
    CHANGING
      ct_fieldcat      = gt_alv[].

  CLEAR gs_alv.
  gs_alv-sel_mode = 'A'.
  gs_alv-zebra = 'X'.

  gs_alv-grid_title = 'Inventory Report'.
  gs_alv-no_toolbar = 'X'.

  MOVE-CORRESPONDING gs_alv TO it_alv[].
ENDFORM.