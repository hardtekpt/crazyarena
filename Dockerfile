# Dockerfile for the crazyflie flying arena 

# Start from the osrf ros image
FROM osrf/ros:noetic-desktop-full

# Setup a user 
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/crazyuser && \
    echo "crazyuser:x:${uid}:${gid}:crazyuser,,,:/home/crazyuser:/bin/bash" >> /etc/passwd && \
    echo "crazyuser:x:${uid}:" >> /etc/group && \
    echo "crazyuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/crazyuser && \
    chmod 0440 /etc/sudoers.d/crazyuser && \
    chown ${uid}:${gid} -R /home/crazyuser

# Install useful packages
RUN apt-get update
RUN apt-get install -y git && apt-get install -y python3-pip && apt-get install -y nano && apt-get install -y curl

# Install CrazyS dependencies
RUN apt-get install -y ros-noetic-joy ros-noetic-octomap-ros ros-noetic-mavlink
RUN apt-get install -y ros-noetic-octomap-mapping ros-noetic-control-toolbox
RUN apt-get install -y python3-vcstool python3-catkin-tools protobuf-compiler libgoogle-glog-dev

USER crazyuser
RUN rosdep update
USER root
RUN apt-get install python3-rosdep python3-wstool ros-noetic-ros libgoogle-glog-dev

ENV HOME /home/crazyuser
ENV USER crazyuser
USER crazyuser

SHELL ["/bin/bash", "-c"] 

# Setup a workspace and install CrazyS packages
RUN source /opt/ros/noetic/setup.bash && \
    mkdir -p /home/crazyuser/catkin_ws/src && \
    cd /home/crazyuser/catkin_ws/src && \
    catkin_init_workspace && \
    cd /home/crazyuser/catkin_ws/ && \
    catkin init && \
    cd /home/crazyuser/catkin_ws/src && \
    git clone -b dev/ros-noetic https://github.com/gsilano/CrazyS.git && \
    git clone -b med18_gazebo9 https://github.com/gsilano/mav_comm.git

USER root

RUN cd /home/crazyuser/catkin_ws/ && \
    rosdep install --from-paths src -i -r -y

USER crazyuser

RUN source /opt/ros/noetic/setup.bash && \
    cd /home/crazyuser/catkin_ws/ && \
    rosdep update && \
    catkin config --cmake-args -DCMAKE_BUILD_TYPE=Release -DCATKIN_ENABLE_TESTING=False && \
    catkin build

RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "source /home/crazyuser/catkin_ws/devel/setup.bash" >> ~/.bashrc

# Fix to a known issue with gazebo and CrazyS
RUN cd /home/crazyuser/catkin_ws/ && \
    cp build/rotors_gazebo_plugins/libmav_msgs.so devel/lib/

# Crazyswarm installation
ENV CSW_PYTHON="python3"

USER root

RUN apt-get install -y ros-noetic-tf ros-noetic-tf-conversions ros-noetic-joy && \
    apt-get install -y libpcl-dev libusb-1.0-0-dev && \
    apt-get install -y swig lib${CSW_PYTHON}-dev ${CSW_PYTHON}-pip && \
    ${CSW_PYTHON} -m pip install numpy --upgrade && \
    ${CSW_PYTHON} -m pip install pytest PyYAML scipy && \
    apt-get install -y python3-tk


RUN ${CSW_PYTHON} -m pip install vispy

USER crazyuser
WORKDIR /home/crazyuser

RUN git clone https://github.com/USC-ACTLab/crazyswarm.git

RUN source /opt/ros/noetic/setup.bash && \
    cd crazyswarm && \
    ./build.sh

# Verify the installation by running the unit tests
RUN cd crazyswarm/ros_ws/src/crazyswarm/scripts && \
    source ../../../devel/setup.bash && \
    $CSW_PYTHON -m pytest

# Make the workspace visible outside the container
VOLUME /home/crazyuser/catkin_ws
VOLUME /home/crazyuser/crazyswarm