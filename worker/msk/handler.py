import boto3
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError

def get_msk_brokers(cluster_arn):
    """Get MSK brokers with IAM authentication endpoint"""
    client = boto3.client('kafka')
    response = client.get_bootstrap_brokers(ClusterArn=cluster_arn)
    return response['BootstrapBrokerStringSaslIam']

def create_kafka_admin_client(cluster_arn):
    """Create Kafka admin client with IAM auth"""
    return KafkaAdminClient(
        bootstrap_servers=get_msk_brokers(cluster_arn),
        security_protocol='SASL_SSL',
        sasl_mechanism='AWS_MSK_IAM',
        sasl_jaas_config='software.amazon.msk.auth.iam.IAMLoginModule required;',
        sasl_client_callback_handler_class='software.amazon.msk.auth.iam.IAMClientCallbackHandler'
    )

def handler(event, context):
    try:
        # Get parameters from event
        cluster_arn = event['cluster_arn']
        topic_name = event['topic_name']
        partitions = event['partitions']
        replication_factor = event['replication_factor']
        configs = event.get('configs', {})
        
        # Create admin client with IAM auth
        admin_client = create_kafka_admin_client(cluster_arn)
        
        # Create topic definition
        topic = NewTopic(
            name=topic_name,
            num_partitions=partitions,
            replication_factor=replication_factor,
            topic_configs=configs
        )
        
        try:
            admin_client.create_topics([topic])
            return {
                'statusCode': 200,
                'body': f"Topic {topic_name} created successfully"
            }
        except TopicAlreadyExistsError:
            return {
                'statusCode': 200,
                'body': f"Topic {topic_name} already exists"
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Error creating topic: {str(e)}"
        }
    finally:
        if 'admin_client' in locals():
            admin_client.close()