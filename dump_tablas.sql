
--
-- Name: company_profile; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.company_profile (
    company_id uuid NOT NULL,
    profile_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    profile_stage integer DEFAULT 0 NOT NULL,
    profile_completed boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE tenant.company_profile OWNER TO postgres;


CREATE TABLE tenant.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    status text DEFAULT 'reserved'::text NOT NULL,
    total numeric(12,2) DEFAULT 0 NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval) NOT NULL,
    created_by uuid,
    confirmed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    confirmed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    expired_at timestamp with time zone,
    notes text,
    CONSTRAINT orders_status_check CHECK ((status = ANY (ARRAY['reserved'::text, 'paid'::text, 'cancelled'::text, 'expired'::text])))
);


ALTER TABLE tenant.orders OWNER TO postgres;


CREATE TABLE tenant.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    name text NOT NULL,
    price numeric(12,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    image_url text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_product_id uuid,
    variant_code text,
    reserved_stock integer DEFAULT 0 NOT NULL,
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_reserved_stock_check CHECK ((reserved_stock >= 0)),
    CONSTRAINT products_stock_check CHECK ((stock >= 0))
);


ALTER TABLE tenant.products OWNER TO postgres;


CREATE TABLE tenant.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    nombre text,
    apellido text,
    avatar text,
    codigo_empleado text,
    tipo_usuario text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE tenant.users OWNER TO postgres;




CREATE TABLE tenant.crm_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    user_id uuid NOT NULL,
    note text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    type text DEFAULT 'note'::text
);


ALTER TABLE tenant.crm_activities OWNER TO postgres;


CREATE TABLE tenant.crm_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    lead_id uuid NOT NULL,
    type text NOT NULL,
    value text NOT NULL,
    label text,
    is_primary boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE tenant.crm_contacts OWNER TO postgres;


CREATE TABLE tenant.crm_leads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    pipeline_id uuid NOT NULL,
    stage_id uuid NOT NULL,
    assigned_to uuid,
    title text NOT NULL,
    contact_name text,
    value numeric(14,2),
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    address text,
    dni text,
    email text
);

ALTER TABLE tenant.crm_leads OWNER TO postgres;


CREATE TABLE tenant.crm_stages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    pipeline_id uuid NOT NULL,
    name text NOT NULL,
    "position" integer NOT NULL,
    is_closed boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE tenant.crm_stages OWNER TO postgres;


CREATE TABLE tenant.product_metadata (
    product_id uuid NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE tenant.product_metadata OWNER TO postgres;


CREATE TABLE public.trial_feedback (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    meta jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.trial_feedback OWNER TO postgres;

--
-- Name: ai_jobs; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.ai_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0,
    error text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE tenant.ai_jobs OWNER TO postgres;

--
-- Name: categories; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL
);


ALTER TABLE tenant.categories OWNER TO postgres;

--
-- Name: companies; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    is_demo boolean DEFAULT false,
    demo_expires_at timestamp with time zone
);


ALTER TABLE tenant.companies OWNER TO postgres;

--
-- Name: company_profile2; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.company_profile2 (
    company_id uuid NOT NULL,
    company_status text,
    business_scope text,
    rubros text[],
    products_by_rubro jsonb,
    operational_complexity text,
    measurement_units text[],
    variants text[],
    detail_level text,
    movement_frequency text,
    stock_origin text,
    current_tracking_method text,
    tracking_timing text,
    actors_involved text[],
    desired_visibility text[],
    primary_loss text,
    main_pain text,
    tool_expectation text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    profile_completed boolean DEFAULT false NOT NULL,
    CONSTRAINT company_profile_business_scope_check CHECK ((business_scope = ANY (ARRAY['single'::text, 'poly'::text]))),
    CONSTRAINT company_profile_company_status_check CHECK ((company_status = ANY (ARRAY['formal'::text, 'informal'::text, 'in_process'::text]))),
    CONSTRAINT company_profile_current_tracking_method_check CHECK ((current_tracking_method = ANY (ARRAY['none'::text, 'paper'::text, 'excel'::text, 'simple_system'::text, 'multiple'::text]))),
    CONSTRAINT company_profile_detail_level_check CHECK ((detail_level = ANY (ARRAY['basic'::text, 'medium'::text, 'detailed'::text]))),
    CONSTRAINT company_profile_movement_frequency_check CHECK ((movement_frequency = ANY (ARRAY['daily'::text, 'weekly'::text, 'occasional'::text]))),
    CONSTRAINT company_profile_operational_complexity_check CHECK ((operational_complexity = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))),
    CONSTRAINT company_profile_primary_loss_check CHECK ((primary_loss = ANY (ARRAY['products'::text, 'time'::text, 'information'::text, 'money'::text, 'patience'::text]))),
    CONSTRAINT company_profile_stock_origin_check CHECK ((stock_origin = ANY (ARRAY['purchase'::text, 'production'::text, 'mixed'::text]))),
    CONSTRAINT company_profile_tool_expectation_check CHECK ((tool_expectation = ANY (ARRAY['simple'::text, 'safe'::text, 'understand'::text, 'adaptive'::text]))),
    CONSTRAINT company_profile_tracking_timing_check CHECK ((tracking_timing = ANY (ARRAY['moment'::text, 'end_day'::text, 'later'::text, 'never'::text])))
);


ALTER TABLE tenant.company_profile2 OWNER TO postgres;

--
-- Name: order_items; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0)),
    CONSTRAINT order_items_subtotal_check CHECK ((subtotal >= (0)::numeric)),
    CONSTRAINT order_items_unit_price_check CHECK ((unit_price >= (0)::numeric))
);


ALTER TABLE tenant.order_items OWNER TO postgres;

--
-- Name: purchase_items; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.purchase_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    purchase_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    iva_unit numeric(12,2) DEFAULT 0,
    subtotal numeric(14,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    received_quantity integer DEFAULT 0 NOT NULL
);


ALTER TABLE tenant.purchase_items OWNER TO postgres;

--
-- Name: purchase_receipt_items; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.purchase_receipt_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid NOT NULL,
    purchase_item_id uuid NOT NULL,
    quantity_received integer NOT NULL
);


ALTER TABLE tenant.purchase_receipt_items OWNER TO postgres;

--
-- Name: purchase_receipts; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.purchase_receipts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    purchase_id uuid NOT NULL,
    receipt_number text,
    notes text,
    received_by uuid,
    received_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE tenant.purchase_receipts OWNER TO postgres;

--
-- Name: purchases; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.purchases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    supplier text DEFAULT 'Proveedor Desconocido'::text,
    notes text,
    subtotal numeric(14,2) DEFAULT 0 NOT NULL,
    iva numeric(14,2) DEFAULT 0 NOT NULL,
    total numeric(14,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    expected_date date,
    received_at timestamp with time zone,
    status text DEFAULT 'draft'::text NOT NULL,
    payment_status text DEFAULT 'pending'::text NOT NULL,
    supplier_id uuid,
    CONSTRAINT purchases_payment_status_check CHECK ((payment_status = ANY (ARRAY['pending'::text, 'partial'::text, 'paid'::text]))),
    CONSTRAINT purchases_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'confirmed'::text, 'receiving'::text, 'received'::text, 'cancelled'::text])))
);


ALTER TABLE tenant.purchases OWNER TO postgres;

--
-- Name: sale_items; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.sale_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sale_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    CONSTRAINT sale_items_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE tenant.sale_items OWNER TO postgres;

--
-- Name: sale_returns; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.sale_returns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    sale_id uuid NOT NULL,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE tenant.sale_returns OWNER TO postgres;

--
-- Name: sales; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.sales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    total numeric(12,2) NOT NULL,
    payment_method text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    status text DEFAULT 'pending'::text
);


ALTER TABLE tenant.sales OWNER TO postgres;

--
-- Name: stock_movements; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.stock_movements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    product_id uuid NOT NULL,
    movement_type text NOT NULL,
    quantity integer NOT NULL,
    reason text,
    reference_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT stock_movements_movement_type_check CHECK ((movement_type = ANY (ARRAY['sale'::text, 'adjustment'::text, 'purchase'::text, 'return'::text])))
);


ALTER TABLE tenant.stock_movements OWNER TO postgres;

--
-- Name: subcategories; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.subcategories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid,
    name text NOT NULL
);


ALTER TABLE tenant.subcategories OWNER TO postgres;

--
-- Name: suppliers; Type: TABLE; Schema: tenant; Owner: postgres
--

CREATE TABLE tenant.suppliers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    name text NOT NULL,
    tax_id text,
    contact_name text,
    phone text,
    email text,
    address text,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE tenant.suppliers OWNER TO postgres;

