# Start from tensrflow, pytorch (or similar)
ARG BASE_IMAGE=tensorflow/tensorflow:2.2.0-jupyter
FROM $BASE_IMAGE

# Non-root user with sudo access
ARG USERNAME=default
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Java
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Hadoop
ARG HADOOP_VERSION=2.7.7
ARG HADOOP_OPENSTACK_VERSION=2.7.5
ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_OPENSTACK_VERSION=${HADOOP_OPENSTACK_VERSION}
ENV HADOOP_HOME=/usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV HADOOP_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV PATH=$PATH:$HADOOP_HOME/bin

# Spark
ARG SPARK_VERSION=2.3.4
ENV SPARK_VERSION=${SPARK_VERSION}
ENV SPARK_PACKAGE=spark-${SPARK_VERSION}-bin-without-hadoop
ENV SPARK_HOME=/usr/spark-${SPARK_VERSION}
ENV SPARK_DIST_CLASSPATH="$HADOOP_CLASSPATH"
ENV PATH=$PATH:${SPARK_HOME}/bin

# Zeppelin
ARG Z_VERSION=0.8.2
ENV Z_VERSION=${Z_VERSION}
ENV Z_HOME=/usr/zeppelin-$Z_VERSION
ENV ZEPPELIN_HOME=$Z_HOME
ENV ZEPPELIN_CLASSPATH=${HADOOP_CLASSPATH}

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \
    #
    # Install apt deps
    && apt-get -y install \
    sudo \
    openjdk-8-jdk \
    git \
    #
    # Install Hadoop
    && curl -L --retry 3 \
    "http://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
    | gunzip \
    | tar -x -C /usr/ \
    && rm -rf "$HADOOP_HOME/share/doc" \
    && rm -f "$HADOOP_HOME/share/hadoop/tools/lib/hadoop-openstack-${HADOOP_VERSION}.jar" \
    && curl -o "$HADOOP_HOME/share/hadoop/tools/lib/hadoop-openstack-${HADOOP_OPENSTACK_VERSION}.jar" -L --retry 3 \
    "https://tarballs.openstack.org/sahara-extra/dist/hadoop-openstack/master/hadoop-openstack-${HADOOP_OPENSTACK_VERSION}.jar" \
    && chown -R root:root "$HADOOP_HOME" \
    #
    # Install Spark
    && curl -L --retry 3 \
    "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
    | gunzip \
    | tar x -C /usr/ \
    && mv "/usr/$SPARK_PACKAGE" "$SPARK_HOME" \
    && chown -R root:root "$SPARK_HOME" \
    #
    # Install Zeppelin
    && curl -L --retry 3 \
    "http://archive.apache.org/dist/zeppelin/zeppelin-${Z_VERSION}/zeppelin-${Z_VERSION}-bin-all.tgz" \
    | gunzip \
    | tar x -C /usr/ \
    && mv "/usr/zeppelin-${Z_VERSION}-bin-all" "${Z_HOME}" \
    && chown -R root:root "$Z_HOME" \
    #
    # Pip deps
    && pip install pandasql==0.7.3 \
    #
    # Create a non-root user to use if preferred
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch back to dialog
ENV DEBIAN_FRONTEND=dialog

# Set workidir and command
WORKDIR ${Z_HOME}
CMD bin/zeppelin.sh