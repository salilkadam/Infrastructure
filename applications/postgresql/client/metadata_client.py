#!/usr/bin/env python3
"""
Milvus PostgreSQL Metadata Client
A Python client for managing application-level metadata in PostgreSQL
"""

import os
import json
import uuid
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any, Union
import psycopg2
from psycopg2.extras import RealDictCursor, Json
from psycopg2.pool import SimpleConnectionPool

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class MilvusMetadataClient:
    """
    Client for managing Milvus application metadata in PostgreSQL
    """
    
    def __init__(self, 
                 host: str = "postgresql.postgres.svc.cluster.local",
                 port: int = 5432,
                 database: str = "milvus_metadata",
                 user: str = "milvus_user",
                 password: str = "milvus_password",
                 pool_size: int = 5):
        """
        Initialize the metadata client
        
        Args:
            host: PostgreSQL host
            port: PostgreSQL port
            database: Database name
            user: Username
            password: Password
            pool_size: Connection pool size
        """
        self.connection_params = {
            'host': host,
            'port': port,
            'database': database,
            'user': user,
            'password': password
        }
        self.pool_size = pool_size
        self.pool = None
        self._init_pool()
    
    def _init_pool(self):
        """Initialize connection pool"""
        try:
            self.pool = SimpleConnectionPool(
                1, self.pool_size, **self.connection_params
            )
            logger.info("Connection pool initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize connection pool: {e}")
            raise
    
    def _get_connection(self):
        """Get a connection from the pool"""
        if not self.pool:
            self._init_pool()
        return self.pool.getconn()
    
    def _return_connection(self, conn):
        """Return a connection to the pool"""
        if self.pool:
            self.pool.putconn(conn)
    
    def execute_query(self, query: str, params: tuple = None) -> List[Dict]:
        """
        Execute a query and return results
        
        Args:
            query: SQL query
            params: Query parameters
            
        Returns:
            List of dictionaries with results
        """
        conn = None
        try:
            conn = self._get_connection()
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute(query, params)
                if query.strip().upper().startswith('SELECT'):
                    return cursor.fetchall()
                else:
                    conn.commit()
                    return []
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Query execution failed: {e}")
            raise
        finally:
            if conn:
                self._return_connection(conn)
    
    # User Management
    def create_user(self, username: str, email: str, password_hash: str, 
                   role: str = "user") -> Dict:
        """Create a new user"""
        query = """
        INSERT INTO users (username, email, password_hash, role)
        VALUES (%s, %s, %s, %s)
        RETURNING *
        """
        result = self.execute_query(query, (username, email, password_hash, role))
        return dict(result[0]) if result else None
    
    def get_user(self, user_id: str = None, username: str = None) -> Optional[Dict]:
        """Get user by ID or username"""
        if user_id:
            query = "SELECT * FROM users WHERE id = %s"
            params = (user_id,)
        elif username:
            query = "SELECT * FROM users WHERE username = %s"
            params = (username,)
        else:
            raise ValueError("Either user_id or username must be provided")
        
        result = self.execute_query(query, params)
        return dict(result[0]) if result else None
    
    def update_user_last_login(self, user_id: str):
        """Update user's last login timestamp"""
        query = "UPDATE users SET last_login = %s WHERE id = %s"
        self.execute_query(query, (datetime.now(timezone.utc), user_id))
    
    # Collection Management
    def create_collection(self, collection_name: str, dimension: int, 
                         metric_type: str, description: str = None,
                         created_by: str = None, metadata: Dict = None) -> Dict:
        """Create a new collection record"""
        query = """
        INSERT INTO collections (collection_name, dimension, metric_type, 
                                description, created_by, metadata)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING *
        """
        result = self.execute_query(query, (
            collection_name, dimension, metric_type, description,
            created_by, Json(metadata) if metadata else None
        ))
        return dict(result[0]) if result else None
    
    def get_collection(self, collection_id: str = None, 
                      collection_name: str = None) -> Optional[Dict]:
        """Get collection by ID or name"""
        if collection_id:
            query = "SELECT * FROM collections WHERE id = %s"
            params = (collection_id,)
        elif collection_name:
            query = "SELECT * FROM collections WHERE collection_name = %s"
            params = (collection_name,)
        else:
            raise ValueError("Either collection_id or collection_name must be provided")
        
        result = self.execute_query(query, params)
        return dict(result[0]) if result else None
    
    def list_collections(self, status: str = "active") -> List[Dict]:
        """List all collections"""
        query = "SELECT * FROM collections WHERE status = %s ORDER BY created_at DESC"
        result = self.execute_query(query, (status,))
        return [dict(row) for row in result]
    
    def update_collection(self, collection_id: str, **kwargs) -> Dict:
        """Update collection metadata"""
        allowed_fields = ['description', 'index_type', 'partition_key', 'status', 'metadata']
        update_fields = []
        params = []
        
        for field, value in kwargs.items():
            if field in allowed_fields:
                update_fields.append(f"{field} = %s")
                if field == 'metadata':
                    params.append(Json(value))
                else:
                    params.append(value)
        
        if not update_fields:
            raise ValueError("No valid fields to update")
        
        params.append(collection_id)
        query = f"""
        UPDATE collections 
        SET {', '.join(update_fields)}
        WHERE id = %s
        RETURNING *
        """
        result = self.execute_query(query, tuple(params))
        return dict(result[0]) if result else None
    
    # Permission Management
    def grant_permission(self, user_id: str, collection_id: str, 
                        permission_type: str, granted_by: str = None) -> Dict:
        """Grant permission to user for collection"""
        query = """
        INSERT INTO permissions (user_id, collection_id, permission_type, granted_by)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (user_id, collection_id, permission_type) 
        DO UPDATE SET granted_at = CURRENT_TIMESTAMP
        RETURNING *
        """
        result = self.execute_query(query, (user_id, collection_id, permission_type, granted_by))
        return dict(result[0]) if result else None
    
    def check_permission(self, user_id: str, collection_id: str, 
                        permission_type: str) -> bool:
        """Check if user has permission for collection"""
        query = """
        SELECT COUNT(*) as count FROM permissions 
        WHERE user_id = %s AND collection_id = %s AND permission_type = %s
        AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
        """
        result = self.execute_query(query, (user_id, collection_id, permission_type))
        return result[0]['count'] > 0 if result else False
    
    def revoke_permission(self, user_id: str, collection_id: str, 
                         permission_type: str):
        """Revoke permission from user for collection"""
        query = """
        DELETE FROM permissions 
        WHERE user_id = %s AND collection_id = %s AND permission_type = %s
        """
        self.execute_query(query, (user_id, collection_id, permission_type))
    
    # Audit Logging
    def log_audit_event(self, user_id: str, action: str, resource_type: str,
                       resource_id: str = None, details: Dict = None,
                       ip_address: str = None, user_agent: str = None) -> Dict:
        """Log an audit event"""
        query = """
        INSERT INTO audit_logs (user_id, action, resource_type, resource_id, 
                               details, ip_address, user_agent)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """
        result = self.execute_query(query, (
            user_id, action, resource_type, resource_id,
            Json(details) if details else None, ip_address, user_agent
        ))
        return dict(result[0]) if result else None
    
    def get_audit_logs(self, user_id: str = None, action: str = None,
                      resource_type: str = None, limit: int = 100) -> List[Dict]:
        """Get audit logs with optional filters"""
        conditions = []
        params = []
        
        if user_id:
            conditions.append("user_id = %s")
            params.append(user_id)
        if action:
            conditions.append("action = %s")
            params.append(action)
        if resource_type:
            conditions.append("resource_type = %s")
            params.append(resource_type)
        
        where_clause = " AND ".join(conditions) if conditions else "1=1"
        params.append(limit)
        
        query = f"""
        SELECT * FROM audit_logs 
        WHERE {where_clause}
        ORDER BY timestamp DESC 
        LIMIT %s
        """
        result = self.execute_query(query, tuple(params))
        return [dict(row) for row in result]
    
    # Performance Metrics
    def log_performance_metric(self, collection_id: str, operation_type: str,
                              duration_ms: int, success: bool,
                              operation_id: str = None, error_message: str = None,
                              metadata: Dict = None) -> Dict:
        """Log a performance metric"""
        query = """
        INSERT INTO performance_metrics (collection_id, operation_type, 
                                        duration_ms, success, operation_id,
                                        error_message, metadata)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """
        result = self.execute_query(query, (
            collection_id, operation_type, duration_ms, success,
            operation_id, error_message, Json(metadata) if metadata else None
        ))
        return dict(result[0]) if result else None
    
    def get_performance_stats(self, collection_id: str = None, 
                            days: int = 7) -> Dict:
        """Get performance statistics"""
        conditions = []
        params = []
        
        if collection_id:
            conditions.append("collection_id = %s")
            params.append(collection_id)
        
        conditions.append("timestamp >= CURRENT_TIMESTAMP - INTERVAL '%s days'")
        params.append(days)
        
        where_clause = " AND ".join(conditions)
        params.extend([collection_id] if collection_id else [])
        
        query = f"""
        SELECT 
            operation_type,
            COUNT(*) as total_operations,
            AVG(duration_ms) as avg_duration_ms,
            MIN(duration_ms) as min_duration_ms,
            MAX(duration_ms) as max_duration_ms,
            COUNT(CASE WHEN success = true THEN 1 END) as successful_operations,
            COUNT(CASE WHEN success = false THEN 1 END) as failed_operations
        FROM performance_metrics 
        WHERE {where_clause}
        GROUP BY operation_type
        """
        result = self.execute_query(query, tuple(params))
        return [dict(row) for row in result]
    
    # Query Logging
    def log_query(self, user_id: str, collection_id: str, query_type: str,
                  duration_ms: int, success: bool, top_k: int = None,
                  query_vector_dimension: int = None, search_params: Dict = None,
                  result_count: int = None, error_message: str = None) -> Dict:
        """Log a query execution"""
        query = """
        INSERT INTO query_logs (user_id, collection_id, query_type, 
                               duration_ms, success, top_k, query_vector_dimension,
                               search_params, result_count, error_message)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """
        result = self.execute_query(query, (
            user_id, collection_id, query_type, duration_ms, success,
            top_k, query_vector_dimension, Json(search_params) if search_params else None,
            result_count, error_message
        ))
        return dict(result[0]) if result else None
    
    # System Configuration
    def get_config(self, config_key: str) -> Optional[str]:
        """Get system configuration value"""
        query = "SELECT config_value FROM system_config WHERE config_key = %s"
        result = self.execute_query(query, (config_key,))
        return result[0]['config_value'] if result else None
    
    def set_config(self, config_key: str, config_value: str, 
                   config_type: str = "string", description: str = None):
        """Set system configuration value"""
        query = """
        INSERT INTO system_config (config_key, config_value, config_type, description)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (config_key) 
        DO UPDATE SET config_value = EXCLUDED.config_value,
                      config_type = EXCLUDED.config_type,
                      description = EXCLUDED.description,
                      updated_at = CURRENT_TIMESTAMP
        """
        self.execute_query(query, (config_key, config_value, config_type, description))
    
    # Collection Statistics
    def get_collection_stats(self) -> List[Dict]:
        """Get collection statistics"""
        query = "SELECT * FROM collection_stats ORDER BY created_at DESC"
        result = self.execute_query(query)
        return [dict(row) for row in result]
    
    def close(self):
        """Close the connection pool"""
        if self.pool:
            self.pool.closeall()
            logger.info("Connection pool closed")


# Convenience functions for common operations
def create_milvus_collection(client: MilvusMetadataClient, collection_name: str,
                            dimension: int, metric_type: str, user_id: str,
                            description: str = None) -> Dict:
    """Create a collection and grant permissions to the creator"""
    # Create collection record
    collection = client.create_collection(
        collection_name=collection_name,
        dimension=dimension,
        metric_type=metric_type,
        description=description,
        created_by=user_id
    )
    
    # Grant admin permissions to creator
    client.grant_permission(
        user_id=user_id,
        collection_id=collection['id'],
        permission_type='admin',
        granted_by=user_id
    )
    
    # Log the creation
    client.log_audit_event(
        user_id=user_id,
        action='create_collection',
        resource_type='collection',
        resource_id=collection['id'],
        details={'collection_name': collection_name, 'dimension': dimension}
    )
    
    return collection


def log_vector_search(client: MilvusMetadataClient, user_id: str, 
                     collection_id: str, query_vector_dimension: int,
                     top_k: int, duration_ms: int, success: bool,
                     result_count: int = None, search_params: Dict = None,
                     error_message: str = None):
    """Log a vector search operation"""
    # Log the query
    client.log_query(
        user_id=user_id,
        collection_id=collection_id,
        query_type='vector_search',
        duration_ms=duration_ms,
        success=success,
        top_k=top_k,
        query_vector_dimension=query_vector_dimension,
        search_params=search_params,
        result_count=result_count,
        error_message=error_message
    )
    
    # Log performance metric
    client.log_performance_metric(
        collection_id=collection_id,
        operation_type='search',
        duration_ms=duration_ms,
        success=success,
        error_message=error_message,
        metadata={'top_k': top_k, 'result_count': result_count}
    )


if __name__ == "__main__":
    # Example usage
    client = MilvusMetadataClient()
    
    try:
        # Get collection statistics
        stats = client.get_collection_stats()
        print(f"Found {len(stats)} collections")
        
        # Get system configuration
        milvus_endpoint = client.get_config('milvus_api_endpoint')
        print(f"Milvus endpoint: {milvus_endpoint}")
        
    finally:
        client.close() 