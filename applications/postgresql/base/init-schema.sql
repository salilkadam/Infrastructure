-- Milvus Application Metadata Schema
-- This schema is for application-level metadata, not Milvus internal metadata

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Users and Authentication
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Collections metadata
CREATE TABLE IF NOT EXISTS collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    dimension INTEGER NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    index_type VARCHAR(50),
    partition_key VARCHAR(100),
    status VARCHAR(50) DEFAULT 'active',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Collection partitions
CREATE TABLE IF NOT EXISTS collection_partitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_id UUID REFERENCES collections(id) ON DELETE CASCADE,
    partition_name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(collection_id, partition_name)
);

-- Access permissions
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    collection_id UUID REFERENCES collections(id) ON DELETE CASCADE,
    permission_type VARCHAR(50) NOT NULL, -- 'read', 'write', 'admin'
    granted_by UUID REFERENCES users(id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, collection_id, permission_type)
);

-- Audit trails
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL, -- 'collection', 'partition', 'user', etc.
    resource_id VARCHAR(255),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Performance metrics
CREATE TABLE IF NOT EXISTS performance_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_id UUID REFERENCES collections(id),
    operation_type VARCHAR(50) NOT NULL, -- 'search', 'insert', 'delete', 'update'
    operation_id VARCHAR(255),
    duration_ms INTEGER NOT NULL,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    metadata JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Query logs
CREATE TABLE IF NOT EXISTS query_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    collection_id UUID REFERENCES collections(id),
    query_type VARCHAR(50) NOT NULL, -- 'vector_search', 'scalar_search', 'hybrid_search'
    query_vector_dimension INTEGER,
    top_k INTEGER,
    search_params JSONB,
    result_count INTEGER,
    duration_ms INTEGER NOT NULL,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- System configuration
CREATE TABLE IF NOT EXISTS system_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(50) DEFAULT 'string', -- 'string', 'integer', 'boolean', 'json'
    description TEXT,
    is_encrypted BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Data ingestion logs
CREATE TABLE IF NOT EXISTS ingestion_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_id UUID REFERENCES collections(id),
    user_id UUID REFERENCES users(id),
    batch_id VARCHAR(255),
    records_count INTEGER NOT NULL,
    file_size_bytes BIGINT,
    source_type VARCHAR(50), -- 'file', 'api', 'stream'
    status VARCHAR(50) NOT NULL, -- 'pending', 'processing', 'completed', 'failed'
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    metadata JSONB
);

-- Index management
CREATE TABLE IF NOT EXISTS index_management (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_id UUID REFERENCES collections(id),
    index_name VARCHAR(255) NOT NULL,
    index_type VARCHAR(50) NOT NULL,
    index_params JSONB,
    status VARCHAR(50) DEFAULT 'building', -- 'building', 'completed', 'failed'
    progress_percentage INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_timestamp ON performance_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_collection_id ON performance_metrics(collection_id);
CREATE INDEX IF NOT EXISTS idx_query_logs_timestamp ON query_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_query_logs_user_id ON query_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_query_logs_collection_id ON query_logs(collection_id);
CREATE INDEX IF NOT EXISTS idx_permissions_user_id ON permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_permissions_collection_id ON permissions(collection_id);
CREATE INDEX IF NOT EXISTS idx_collections_created_by ON collections(created_by);
CREATE INDEX IF NOT EXISTS idx_ingestion_logs_collection_id ON ingestion_logs(collection_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_logs_status ON ingestion_logs(status);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_collections_updated_at BEFORE UPDATE ON collections FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default system configuration
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES
('milvus_api_endpoint', 'milvus-proxy.milvus.svc.cluster.local:19530', 'string', 'Milvus API endpoint'),
('max_query_timeout', '300', 'integer', 'Maximum query timeout in seconds'),
('default_top_k', '10', 'integer', 'Default top-k for vector searches'),
('enable_audit_logging', 'true', 'boolean', 'Enable audit logging'),
('enable_performance_monitoring', 'true', 'boolean', 'Enable performance monitoring'),
('data_retention_days', '90', 'integer', 'Data retention period in days')
ON CONFLICT (config_key) DO NOTHING;

-- Insert default admin user
INSERT INTO users (username, email, password_hash, role) VALUES
('admin', 'admin@askcollections.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/HS.iK8i', 'admin') -- password: admin123
ON CONFLICT (username) DO NOTHING;

-- Create a view for collection statistics
CREATE OR REPLACE VIEW collection_stats AS
SELECT 
    c.id,
    c.collection_name,
    c.description,
    c.dimension,
    c.metric_type,
    c.status,
    c.created_at,
    COUNT(DISTINCT cp.id) as partition_count,
    COUNT(DISTINCT p.user_id) as user_count,
    AVG(pm.duration_ms) as avg_query_duration,
    COUNT(pm.id) as total_queries,
    COUNT(CASE WHEN pm.success = true THEN 1 END) as successful_queries
FROM collections c
LEFT JOIN collection_partitions cp ON c.id = cp.collection_id
LEFT JOIN permissions p ON c.id = p.collection_id
LEFT JOIN performance_metrics pm ON c.id = pm.collection_id
GROUP BY c.id, c.collection_name, c.description, c.dimension, c.metric_type, c.status, c.created_at;

-- Grant permissions to milvus_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO milvus_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO milvus_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO milvus_user; 